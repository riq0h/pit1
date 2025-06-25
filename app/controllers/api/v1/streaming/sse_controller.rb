# frozen_string_literal: true

module Api
  module V1
    module Streaming
      class SseController < ActionController::Base
        include ActionController::Live
        
        before_action :authenticate_user!
        
        def stream
          response.headers['Content-Type'] = 'text/event-stream'
          response.headers['Cache-Control'] = 'no-cache'
          response.headers['X-Accel-Buffering'] = 'no'
          response.headers['Connection'] = 'keep-alive'
          
          stream_type = params[:stream] || 'user'
          
          begin
            # 初期接続メッセージ
            response.stream.write("event: connected\ndata: {\"stream\":\"#{stream_type}\"}\n\n")
            
            # ハートビートスレッド
            heartbeat_thread = start_heartbeat
            
            # チャンネルを決定
            channels = determine_channels(stream_type)
            
            # Solid Cableのサブスクリプションを設定
            subscription_ids = []
            channels.each do |channel|
              subscription_ids << subscribe_to_channel(channel)
            end
            
            # メッセージポーリングループ
            loop do
              subscription_ids.each do |sub_id|
                messages = poll_messages(sub_id)
                messages.each do |message|
                  broadcast_message(message)
                end
              end
              sleep 0.1
            end
            
          rescue ActionController::Live::ClientDisconnected
            Rails.logger.info "SSE client disconnected"
          rescue StandardError => e
            Rails.logger.error "SSE streaming error: #{e.message}"
            response.stream.write("event: error\ndata: {\"error\":\"#{e.message}\"}\n\n")
          ensure
            heartbeat_thread&.kill
            subscription_ids&.each { |sub_id| unsubscribe_from_channel(sub_id) }
            response.stream.close
          end
        end
        
        private
        
        def authenticate_user!
          token = request.headers['Authorization']&.gsub('Bearer ', '') || params[:access_token]
          
          @access_token = Doorkeeper::AccessToken.by_token(token)
          @current_user = Actor.find_by(id: @access_token&.resource_owner_id) if @access_token&.acceptable?
          
          return head :unauthorized unless @current_user
        end
        
        def determine_channels(stream_type)
          case stream_type
          when 'user'
            [
              "timeline:user:#{@current_user.id}",
              "timeline:home:#{@current_user.id}",
              "notifications:#{@current_user.id}"
            ]
          when 'public'
            ['timeline:public']
          when 'public:local'
            ['timeline:public:local']
          when 'direct'
            ["timeline:direct:#{@current_user.id}"]
          when /\Ahashtag(?::local)?\z/
            hashtag = params[:tag]&.downcase
            return [] if hashtag.blank?
            
            channel = stream_type.include?('local') ? "hashtag:#{hashtag}:local" : "hashtag:#{hashtag}"
            [channel]
          when /\Alist:(\d+)\z/
            list_id = $1
            list = @current_user.lists.find_by(id: list_id)
            return [] unless list
            
            ["list:#{list_id}"]
          else
            []
          end
        end
        
        def start_heartbeat
          Thread.new do
            loop do
              response.stream.write(":heartbeat\n\n")
              sleep 30
            end
          rescue IOError
            # ストリームが閉じられた
          end
        end
        
        def subscribe_to_channel(channel)
          # Solid CableのメッセージテーブルにサブスクリプションIDを生成
          subscription_id = SecureRandom.uuid
          
          # サブスクリプション情報を保存（メモリまたはDBに）
          Rails.cache.write(
            "sse_subscription:#{subscription_id}",
            { channel: channel, user_id: @current_user.id },
            expires_in: 1.hour
          )
          
          subscription_id
        end
        
        def unsubscribe_from_channel(subscription_id)
          Rails.cache.delete("sse_subscription:#{subscription_id}")
        end
        
        def poll_messages(subscription_id)
          subscription = Rails.cache.read("sse_subscription:#{subscription_id}")
          return [] unless subscription
          
          channel = subscription[:channel]
          
          # Solid Cableのメッセージを直接クエリ
          # Action Cableがブロードキャストしたメッセージを取得
          messages = SolidCable::Message
            .where(channel: channel)
            .where('created_at > ?', @last_poll_time || 1.second.ago)
            .order(created_at: :asc)
            .limit(10)
          
          @last_poll_time = Time.current
          
          messages.map(&:payload)
        rescue StandardError => e
          Rails.logger.error "Failed to poll messages: #{e.message}"
          []
        end
        
        def broadcast_message(message)
          return unless message.present?
          
          begin
            data = JSON.parse(message)
            
            # SSE形式でメッセージを送信
            response.stream.write("event: #{data['event'] || 'message'}\n")
            response.stream.write("data: #{data['payload'].to_json}\n\n")
          rescue JSON::ParserError => e
            Rails.logger.error "Invalid message format: #{e.message}"
          end
        end
      end
    end
  end
end