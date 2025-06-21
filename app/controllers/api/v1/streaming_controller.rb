# frozen_string_literal: true

module Api
  module V1
    class StreamingController < Api::BaseController
      include ActionController::Live

      before_action :doorkeeper_authorize!
      before_action :set_cors_headers

      # GET /api/v1/streaming
      def index
        response.headers['Content-Type'] = 'text/event-stream'
        response.headers['Cache-Control'] = 'no-cache'
        response.headers['Connection'] = 'keep-alive'
        response.headers['Access-Control-Allow-Origin'] = '*'
        response.headers['Access-Control-Allow-Headers'] = 'Authorization'

        stream = params[:stream] || 'user'

        begin
          case stream
          when 'user'
            stream_user_events
          when 'public'
            stream_public_events
          when 'public:local'
            stream_local_public_events
          when /\Ahashtag(:local)?\z/
            stream_hashtag_events(stream.include?('local'))
          when /\Alist:\d+\z/
            list_id = stream.split(':').last
            stream_list_events(list_id)
          else
            send_event('error', { error: 'Invalid stream type' })
          end
        rescue IOError, ActionController::Live::ClientDisconnected
          Rails.logger.info "Streaming client disconnected: #{current_user&.username}"
        ensure
          response.stream.close
        end
      end

      private

      def stream_user_events
        # ユーザ固有のイベントストリーム
        send_heartbeat

        last_status_id = ActivityPubObject.where(local: true, object_type: 'Note').maximum(:id) || 0
        last_notification_id = current_user.notifications.maximum(:id) || 0

        loop do
          sleep 2 # 2秒間隔でポーリング

          # 新しい投稿をチェック
          new_statuses = ActivityPubObject.where(local: true, object_type: 'Note')
                                          .where('id > ?', last_status_id)
                                          .order(:id)

          new_statuses.each do |status|
            # ホームタイムラインに表示される投稿かチェック
            send_event('update', serialize_status_for_streaming(status)) if should_include_in_home_timeline?(status)
            last_status_id = status.id
          end

          # 新しい通知をチェック
          new_notifications = current_user.notifications.where('id > ?', last_notification_id).order(:id)

          new_notifications.each do |notification|
            send_event('notification', serialize_notification_for_streaming(notification))
            last_notification_id = notification.id
          end

          # 定期的なハートビート
          send_heartbeat
        end
      end

      def stream_public_events
        send_heartbeat

        last_status_id = ActivityPubObject.where(local: true, object_type: 'Note').maximum(:id) || 0

        loop do
          sleep 3 # 3秒間隔でポーリング

          new_statuses = ActivityPubObject.where(local: true, object_type: 'Note')
                                          .where('id > ?', last_status_id)
                                          .where(visibility: 'public')
                                          .order(:id)

          new_statuses.each do |status|
            send_event('update', serialize_status_for_streaming(status))
            last_status_id = status.id
          end

          send_heartbeat
        end
      end

      def stream_local_public_events
        # ローカル公開タイムライン（publicと同じ実装）
        stream_public_events
      end

      def stream_hashtag_events(local_only = false)
        hashtag = params[:tag]
        return if hashtag.blank?

        send_heartbeat

        last_status_id = ActivityPubObject.joins(:tags)
                                          .where(tags: { name: hashtag.downcase })
                                          .maximum(:id) || 0

        loop do
          sleep 3

          query = ActivityPubObject.joins(:tags)
                                   .where(tags: { name: hashtag.downcase })
                                   .where('activity_pub_objects.id > ?', last_status_id)

          query = query.where(local: true) if local_only

          new_statuses = query.order(:id)

          new_statuses.each do |status|
            send_event('update', serialize_status_for_streaming(status)) if status.visibility == 'public'
            last_status_id = status.id
          end

          send_heartbeat
        end
      end

      def stream_list_events(list_id)
        list = current_user.lists.find_by(id: list_id)
        return unless list

        send_heartbeat

        member_actor_ids = list.members.pluck(:id)
        last_status_id = ActivityPubObject.where(actor_id: member_actor_ids).maximum(:id) || 0

        loop do
          sleep 2

          new_statuses = ActivityPubObject.where(actor_id: member_actor_ids)
                                          .where('id > ?', last_status_id)
                                          .where(object_type: 'Note')
                                          .order(:id)

          new_statuses.each do |status|
            send_event('update', serialize_status_for_streaming(status))
            last_status_id = status.id
          end

          send_heartbeat
        end
      end

      def should_include_in_home_timeline?(status)
        # ホームタイムラインの表示ロジック
        return false unless status.object_type == 'Note'

        # 自分の投稿
        return true if status.actor_id == current_user.id

        # フォローしているユーザの投稿
        return true if current_user.following.exists?(id: status.actor_id)

        # メンションされている投稿
        return true if status.mentions.exists?(actor_id: current_user.id)

        false
      end

      def serialize_status_for_streaming(status)
        # 簡略化されたシリアライゼーション
        {
          id: status.id.to_s,
          created_at: status.published_at&.iso8601,
          content: status.content,
          account: {
            id: status.actor.id.to_s,
            username: status.actor.username,
            acct: status.actor.acct,
            display_name: status.actor.display_name
          }
        }
      end

      def serialize_notification_for_streaming(notification)
        # 簡略化されたシリアライゼーション
        {
          id: notification.id.to_s,
          type: notification.notification_type,
          created_at: notification.created_at.iso8601,
          account: {
            id: notification.from_actor.id.to_s,
            username: notification.from_actor.username,
            acct: notification.from_actor.acct,
            display_name: notification.from_actor.display_name
          }
        }
      end

      def send_heartbeat
        response.stream.write(":\n\n")
      end

      def send_event(event_type, data)
        response.stream.write("event: #{event_type}\n")
        response.stream.write("data: #{data.to_json}\n\n")
      end

      def set_cors_headers
        response.headers['Access-Control-Allow-Origin'] = '*'
        response.headers['Access-Control-Allow-Methods'] = 'GET, OPTIONS'
        response.headers['Access-Control-Allow-Headers'] = 'Authorization, Content-Type'
      end
    end
  end
end
