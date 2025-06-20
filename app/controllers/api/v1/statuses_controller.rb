# frozen_string_literal: true

module Api
  module V1
    class StatusesController < Api::BaseController
      include AccountSerializer
      include StatusSerializer
      include MediaSerializer
      include MentionTagSerializer
      include StatusActivityHandlers
      include StatusSerializationHelper
      include TextLinkingHelper
      before_action :doorkeeper_authorize!, except: [:show]
      before_action :doorkeeper_authorize!, only: [:show], if: -> { request.authorization.present? }
      before_action :set_status, except: [:create]

      # GET /api/v1/statuses/:id
      def show
        render json: serialized_status(@status)
      end

      # GET /api/v1/statuses/:id/context
      def context
        ancestors = build_ancestors(@status)
        descendants = build_descendants(@status)
        
        render json: {
          ancestors: ancestors.map { |status| serialized_status(status) },
          descendants: descendants.map { |status| serialized_status(status) }
        }
      end

      # POST /api/v1/statuses
      def create
        return render json: { error: 'This action requires authentication' }, status: :unauthorized unless current_user

        @status = build_status_object

        if @status.save
          process_mentions_and_tags
          attach_media_to_status if @media_ids&.any?
          handle_direct_message_conversation if @status.visibility == 'direct'
          create_activity_for_status
          render json: serialized_status(@status), status: :created
        else
          render_validation_error(@status)
        end
      end

      # POST /api/v1/statuses/:id/favourite
      def favourite
        return render json: { error: 'This action requires authentication' }, status: :unauthorized unless current_user

        favourite = current_user.favourites.find_or_create_by(object: @status)

        if favourite.persisted?
          create_like_activity(@status)
          create_favourite_notification(favourite, @status)
          render json: serialized_status(@status)
        else
          render json: { error: 'Failed to favourite status' }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/statuses/:id/unfavourite
      def unfavourite
        return render json: { error: 'This action requires authentication' }, status: :unauthorized unless current_user

        favourite = current_user.favourites.find_by(object: @status)

        if favourite
          create_undo_like_activity(@status, favourite)
          favourite.destroy
        end

        render json: serialized_status(@status)
      end

      # POST /api/v1/statuses/:id/reblog
      def reblog
        return render json: { error: 'This action requires authentication' }, status: :unauthorized unless current_user

        reblog = current_user.reblogs.find_or_create_by(object: @status)

        if reblog.persisted?
          create_announce_activity(@status)
          create_reblog_notification(reblog, @status)
          render json: serialized_status(@status)
        else
          render json: { error: 'Failed to reblog status' }, status: :unprocessable_entity
        end
      end

      # GET /api/v1/statuses/:id/reblogged_by
      def reblogged_by
        limit = [params.fetch(:limit, 40).to_i, 80].min
        reblogs = @status.reblogs.includes(:actor).limit(limit)
        accounts = reblogs.map(&:actor)
        render json: accounts.map { |account| serialized_account(account) }
      end

      # GET /api/v1/statuses/:id/favourited_by
      def favourited_by
        limit = [params.fetch(:limit, 40).to_i, 80].min
        favourites = @status.favourites.includes(:actor).limit(limit)
        accounts = favourites.map(&:actor)
        render json: accounts.map { |account| serialized_account(account) }
      end

      # POST /api/v1/statuses/:id/unreblog
      def unreblog
        return render json: { error: 'This action requires authentication' }, status: :unauthorized unless current_user

        reblog = current_user.reblogs.find_by(object: @status)

        if reblog
          create_undo_announce_activity(@status, reblog)
          reblog.destroy
        end

        render json: serialized_status(@status)
      end

      # POST /api/v1/statuses/:id/pin
      def pin
        return render json: { error: 'This action requires authentication' }, status: :unauthorized unless current_user
        return render json: { error: 'You can only pin your own statuses' }, status: :unprocessable_entity unless @status.actor == current_user

        # Mastodonの制限: 最大5個まで
        if current_user.pinned_statuses.count >= 5
          return render json: { error: 'You have already pinned the maximum number of statuses' }, status: :unprocessable_entity
        end

        pinned_status = current_user.pinned_statuses.find_or_create_by(object: @status)

        if pinned_status.persisted?
          render json: serialized_status(@status)
        else
          render json: { error: 'Failed to pin status' }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/statuses/:id/unpin
      def unpin
        return render json: { error: 'This action requires authentication' }, status: :unauthorized unless current_user

        pinned_status = current_user.pinned_statuses.find_by(object: @status)
        pinned_status&.destroy

        render json: serialized_status(@status)
      end

      # POST /api/v1/statuses/:id/bookmark
      def bookmark
        doorkeeper_authorize! :write
        return render json: { error: 'This action requires authentication' }, status: :unauthorized unless current_user

        bookmark = current_user.bookmarks.find_or_create_by(object: @status)

        if bookmark.persisted?
          render json: serialized_status(@status)
        else
          render json: { error: 'Failed to bookmark status' }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/statuses/:id/unbookmark
      def unbookmark
        doorkeeper_authorize! :write
        return render json: { error: 'This action requires authentication' }, status: :unauthorized unless current_user

        bookmark = current_user.bookmarks.find_by(object: @status)
        bookmark&.destroy

        render json: serialized_status(@status)
      end

      # PUT /api/v1/statuses/:id
      def update
        return render json: { error: 'This action requires authentication' }, status: :unauthorized unless current_user
        return render json: { error: 'Not authorized' }, status: :forbidden unless @status.actor == current_user

        if @status.update(status_params)
          render json: serialized_status(@status)
        else
          render json: { error: 'Validation failed', details: @status.errors.full_messages },
                 status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/statuses/:id
      def destroy
        return render json: { error: 'This action requires authentication' }, status: :unauthorized unless current_user
        return render json: { error: 'Not authorized' }, status: :forbidden unless @status.actor == current_user

        # Create Delete activity
        current_user.activities.create!(
          ap_id: generate_delete_activity_ap_id(@status),
          activity_type: 'Delete',
          target_ap_id: @status.ap_id,
          published_at: Time.current,
          local: true,
          processed: true
        )

        @status.destroy
        render json: serialized_status(@status)
      end

      private

      def build_status_object
        current_user.objects.build(status_creation_params)
      end

      def status_creation_params
        status_params.merge(
          object_type: 'Note',
          published_at: Time.current,
          local: true,
          ap_id: generate_status_ap_id
        )
      end

      def create_activity_for_status
        create_activity = current_user.activities.create!(
          ap_id: generate_activity_ap_id(@status),
          activity_type: 'Create',
          object: @status,
          published_at: Time.current,
          local: true,
          processed: true
        )

        # Queue for federation delivery to followers
        deliver_create_activity(create_activity)
      end

      def deliver_create_activity(create_activity)
        # メンションされたアクター（外部）のinboxは常に配信対象
        mentioned_inboxes = @status.mentioned_actors.where(local: false).pluck(:inbox_url)
        all_inboxes = mentioned_inboxes.dup

        case @status.visibility
        when 'public'
          # Public投稿：フォロワー + メンションされたアクター
          follower_inboxes = current_user.followers.where(local: false).pluck(:inbox_url)
          all_inboxes.concat(follower_inboxes)
        when 'unlisted'
          # Unlisted投稿：フォロワー + メンションされたアクター
          follower_inboxes = current_user.followers.where(local: false).pluck(:inbox_url)
          all_inboxes.concat(follower_inboxes)
        when 'private', 'followers_only'
          # フォロワー限定：フォロワー + メンションされたアクター
          follower_inboxes = current_user.followers.where(local: false).pluck(:inbox_url)
          all_inboxes.concat(follower_inboxes)
        when 'direct'
          # DM：メンションされたアクターのみ（既に all_inboxes に含まれている）
        end

        # 重複を除去して配信
        unique_inboxes = all_inboxes.uniq.compact
        SendActivityJob.perform_later(create_activity.id, unique_inboxes) if unique_inboxes.any?
      end

      def attach_media_to_status
        media_attachments = current_user.media_attachments.where(id: @media_ids, object_id: nil)
        media_attachments.update_all(object_id: @status.id)
      end

      def render_validation_error(object)
        render json: {
          error: 'Validation failed',
          details: object.errors.full_messages
        }, status: :unprocessable_entity
      end

      def set_status
        @status = ActivityPubObject.where(object_type: 'Note')
                                   .find(params[:id])
      end

      def status_params
        permitted_params = permit_status_params
        transformed_params = transform_param_keys(permitted_params)
        process_reply_to_id(transformed_params)
        extract_media_and_mentions(transformed_params)
        apply_default_visibility(transformed_params)
        transformed_params
      end

      def permit_status_params
        params.permit(:status, :in_reply_to_id, :sensitive, :spoiler_text, :visibility, :language, media_ids: [], mentions: [])
      end

      def transform_param_keys(permitted_params)
        permitted_params.transform_keys do |key|
          case key
          when 'status' then 'content'
          when 'spoiler_text' then 'summary'
          when 'in_reply_to_id' then 'in_reply_to_ap_id'
          else key
          end
        end
      end

      def process_reply_to_id(transformed_params)
        return if transformed_params['in_reply_to_ap_id'].blank?

        reply_id = transformed_params['in_reply_to_ap_id']
        transformed_params['in_reply_to_ap_id'] = convert_reply_id_to_ap_id(reply_id)
      end

      def convert_reply_id_to_ap_id(reply_id)
        return reply_id if reply_id.start_with?('http')

        in_reply_to = ActivityPubObject.find_by(id: reply_id)
        in_reply_to&.ap_id
      end

      def extract_media_and_mentions(transformed_params)
        @media_ids = transformed_params.delete('media_ids')
        @mentions = transformed_params.delete('mentions')
      end

      def apply_default_visibility(transformed_params)
        transformed_params['visibility'] ||= 'public'
      end

      def handle_direct_message_conversation
        return unless @status.visibility == 'direct'

        # DMの場合はメンションされたアクターを参加者として追加
        mentioned_actors = @status.mentioned_actors.to_a
        participants = [current_user] + mentioned_actors

        # 会話を作成または取得
        conversation = Conversation.find_or_create_for_actors(participants)

        # ステータスを会話に関連付け
        @status.update!(conversation: conversation)

        # 会話の最新ステータスを更新
        conversation.update_last_status!(@status)
      end

      def process_mentions_and_tags
        return unless @status.content

        # mention配列パラメータが提供されている場合はそれを優先
        if @mentions.present?
          process_explicit_mentions(@mentions)
        else
          # フォールバック：本文パース
          parser = TextParser.new(@status.content)
          parser.process_for_object(@status)
        end

        # メンション処理後、contentをHTMLリンクに変換
        convert_mentions_to_html_links
      end

      def process_explicit_mentions(mentions_param)
        # mention配列からメンションを処理
        mentions_param.each do |mention_data|
          actor = find_actor_for_mention(mention_data)
          next unless actor

          @status.mentions.find_or_create_by(actor: actor)
        end

        # ハッシュタグは本文パース
        parser = TextParser.new(@status.content)
        parser.extract_hashtags
        parser.create_hashtags_for_object(@status)
      end

      def find_actor_for_mention(mention_data)
        username, domain = extract_username_and_domain(mention_data)
        return nil unless username

        find_actor_by_username_and_domain(username, domain)
      end

      def extract_username_and_domain(mention_data)
        case mention_data
        when String
          mention_data.split('@', 2)
        when Hash
          extract_from_hash(mention_data)
        else
          [nil, nil]
        end
      end

      def extract_from_hash(mention_data)
        username = mention_data[:username] || mention_data['username']
        domain = mention_data[:domain] || mention_data['domain']

        if username.nil?
          acct = mention_data[:acct] || mention_data['acct']
          acct&.split('@', 2) || [nil, nil]
        else
          [username, domain]
        end
      end

      def find_actor_by_username_and_domain(username, domain)
        if domain.present?
          Actor.find_by(username: username, domain: domain)
        else
          Actor.find_by(username: username, local: true)
        end
      end

      def generate_activity_ap_id(status)
        "#{status.ap_id}#activity"
      end

      def generate_delete_activity_ap_id(status)
        "#{status.ap_id}#delete-#{Time.current.to_i}"
      end

      def generate_status_ap_id
        local_domain = Rails.application.config.activitypub.domain
        scheme = Rails.env.production? ? 'https' : 'http'
        "#{scheme}://#{local_domain}/users/#{current_user.username}/posts/#{Letter::Snowflake.generate}"
      end

      def build_ancestors(status)
        return [] unless status.in_reply_to_ap_id.present?
        
        ancestors = []
        current_status = status
        
        while current_status.in_reply_to_ap_id.present?
          parent = ActivityPubObject.find_by(ap_id: current_status.in_reply_to_ap_id)
          break unless parent
          
          ancestors.unshift(parent)
          current_status = parent
        end
        
        ancestors
      end

      def build_descendants(status)
        ActivityPubObject.where(in_reply_to_ap_id: status.ap_id)
                         .order(:published_at)
                         .limit(20)
      end

      def create_favourite_notification(favourite, status)
        return if favourite.actor == status.actor

        Notification.create_favourite_notification(favourite, status)
      end

      def create_reblog_notification(reblog, status)
        return if reblog.actor == status.actor

        Notification.create_reblog_notification(reblog, status)
      end

      def convert_mentions_to_html_links
        return if @status.content.blank?
        return if @status.content.include?('<a ') # 既にHTMLリンクが含まれている場合はスキップ

        # 投稿作成時にすべての処理を行う（フロントエンド処理を簡素化するため）
        # 1. @username@domain 形式のメンションをHTMLリンクに変換
        updated_content = apply_mention_links(@status.content)
        
        # 2. URLをHTMLリンクに変換  
        updated_content = apply_url_links(updated_content)
        
        # 3. 絵文字をHTMLに変換
        updated_content = EmojiParser.new(updated_content).parse
        
        @status.update_column(:content, updated_content) if updated_content != @status.content
      end
    end
  end
end
