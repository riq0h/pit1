# frozen_string_literal: true

module Api
  module V1
    class AccountsController < Api::BaseController
      include StatusSerializationHelper
      before_action :doorkeeper_authorize!, except: [:show]
      before_action :doorkeeper_authorize!, only: [:show], if: -> { request.authorization.present? }
      before_action :set_account, only: %i[show statuses followers following follow unfollow block unblock mute unmute note]
      before_action :set_account_for_featured_tags, only: [:featured_tags]

      # GET /api/v1/accounts/verify_credentials
      def verify_credentials
        doorkeeper_authorize!
        return render json: { error: 'This action requires authentication' }, status: :unauthorized unless current_user

        render json: serialized_account(current_user, is_self: true)
      end

      # GET /api/v1/accounts/:id
      def show
        render json: serialized_account(@account)
      end

      # PATCH /api/v1/accounts/update_credentials
      def update_credentials
        return render_unauthorized unless current_user

        process_file_uploads
        update_account_attributes
      end

      # GET /api/v1/accounts/:id/statuses
      def statuses
        pinned_only = params[:pinned] == 'true'
        exclude_replies = params[:exclude_replies] == 'true'
        exclude_reblogs = params[:exclude_reblogs] == 'true'
        only_media = params[:only_media] == 'true'
        limit = [params.fetch(:limit, 20).to_i, 40].min

        if pinned_only
          # Pinned statusesのみを返す
          pinned_statuses = @account.pinned_statuses
                                    .includes(object: %i[actor media_attachments mentions tags poll])
                                    .ordered
                                    .limit(limit)
          statuses = pinned_statuses.map(&:object)
        else
          # 通常の投稿一覧（pinned statusesを最上部に表示）
          base_query = @account.objects.where(object_type: ['Note', 'Question'])

          # ローカル投稿とリモート投稿の両方を含める
          base_query = base_query.where(local: [true, false])

          # リプライ除外
          base_query = base_query.where(in_reply_to_ap_id: nil) if exclude_replies

          # メディア添付のみ
          base_query = base_query.joins(:media_attachments).distinct if only_media

          # 通常の投稿を取得（ページネーション対応）
          regular_statuses = base_query.includes(:poll, :actor, :media_attachments, :mentions, :tags).order(published_at: :desc)
          regular_statuses = apply_timeline_pagination(regular_statuses)
          regular_statuses = regular_statuses.limit(limit)

          # Pinned statusesは最初のページでのみ表示（ページネーションパラメータがない場合のみ）
          is_first_page = params[:max_id].blank? && params[:since_id].blank? && params[:min_id].blank?

          if is_first_page
            # Pinned statusesを取得（全ユーザ対象）
            pinned_objects = @account.pinned_statuses
                                     .includes(object: %i[actor media_attachments mentions tags poll])
                                     .ordered
                                     .map(&:object)

            # Pinned statusesを除いた通常投稿
            regular_statuses = regular_statuses.where.not(id: pinned_objects.map(&:id)) if pinned_objects.any?

            # Pinned statusesを先頭に配置
            statuses = pinned_objects + regular_statuses.to_a

            # 制限数に切り詰める
            statuses = statuses.first(limit)
          else
            # ページネーション中はPinnedを表示しない
            statuses = regular_statuses.to_a
          end
        end

        render json: statuses.map { |status| serialized_status(status) }
      end

      # GET /api/v1/accounts/:id/followers
      def followers
        if @account.local?
          followers = @account.followers.limit(40)
          render json: followers.map { |follower| serialized_account(follower) }
        else
          # 外部アカウントの場合は空配列を返す（クライアントが外部サーバから直接取得するため）
          render json: []
        end
      end

      # GET /api/v1/accounts/:id/following
      def following
        if @account.local?
          following = @account.followed_actors.limit(40)
          render json: following.map { |followed| serialized_account(followed) }
        else
          # 外部アカウントの場合は空配列を返す（クライアントが外部サーバから直接取得するため）
          render json: []
        end
      end

      # POST /api/v1/accounts/:id/follow
      def follow
        return render_follow_error if cannot_follow_self?

        existing_follow = find_existing_follow
        return render_existing_follow_response(existing_follow) if existing_follow

        create_new_follow
      end

      # POST /api/v1/accounts/:id/unfollow
      def unfollow
        follow = current_user.follows.find_by(target_actor: @account)
        follow&.unfollow!

        render json: serialized_relationship(@account)
      end

      # POST /api/v1/accounts/:id/block
      def block
        return render_block_authentication_error unless current_user
        return render_block_self_error if @account == current_user

        process_block_action
        render json: serialized_relationship(@account)
      end

      # POST /api/v1/accounts/:id/unblock
      def unblock
        return render json: { error: 'This action requires authentication' }, status: :unauthorized unless current_user

        block = current_user.blocks.find_by(target_actor: @account)
        block&.destroy

        render json: serialized_relationship(@account)
      end

      # POST /api/v1/accounts/:id/mute
      def mute
        return render json: { error: 'This action requires authentication' }, status: :unauthorized unless current_user
        return render json: { error: 'Cannot mute yourself' }, status: :unprocessable_entity if @account == current_user

        notifications = params[:notifications] != false
        mute = current_user.mutes.find_or_initialize_by(target_actor: @account)
        mute.notifications = notifications
        mute.save!

        render json: serialized_relationship(@account)
      end

      # POST /api/v1/accounts/:id/unmute
      def unmute
        return render json: { error: 'This action requires authentication' }, status: :unauthorized unless current_user

        mute = current_user.mutes.find_by(target_actor: @account)
        mute&.destroy

        render json: serialized_relationship(@account)
      end

      # GET /api/v1/accounts/search
      def search
        return unless doorkeeper_authorize! :read
        return render json: { error: 'This action requires authentication' }, status: :unauthorized unless current_user

        query = params[:q].to_s.strip
        limit = [params.fetch(:limit, 40).to_i, 80].min
        resolve = params[:resolve] == 'true'

        return render json: [] if query.blank?

        accounts = search_accounts(query, limit, resolve)
        render json: accounts.map { |account| serialized_account(account) }
      end

      # GET /api/v1/accounts/:id/featured_tags
      def featured_tags
        featured_tags = @account.featured_tags.includes(:tag).recent
        render json: featured_tags.map { |featured_tag| serialized_featured_tag(featured_tag) }
      end

      # GET /api/v1/accounts/lookup
      def lookup
        return unless doorkeeper_authorize! :read
        return render json: { error: 'This action requires authentication' }, status: :unauthorized unless current_user

        acct = params[:acct].to_s.strip
        return render json: { error: 'Missing acct parameter' }, status: :unprocessable_entity if acct.blank?

        account = lookup_account(acct)
        if account
          render json: serialized_account(account)
        else
          render json: { error: 'Record not found' }, status: :not_found
        end
      end

      # GET /api/v1/accounts/relationships
      def relationships
        return render json: { error: 'This action requires authentication' }, status: :unauthorized unless current_user

        account_ids = Array(params[:id]).map(&:to_i)
        accounts = Actor.where(id: account_ids)

        # すべての要求されたIDに対してrelationshipを返す（存在しないものは空のrelationship）
        relationships = account_ids.map do |id|
          account = accounts.find { |a| a.id == id }
          if account
            serialized_relationship(account)
          else
            # 存在しないアカウントの場合、デフォルトrelationshipを返す
            {
              id: id.to_s,
              following: false,
              followed_by: false,
              showing_reblogs: true,
              notifying: false,
              requested: false,
              blocking: false,
              blocked_by: false,
              domain_blocking: false,
              muting: false,
              muting_notifications: false,
              endorsed: false
            }
          end
        end

        render json: relationships
      end

      # POST /api/v1/accounts/:id/note
      def note
        return render json: { error: 'This action requires authentication' }, status: :unauthorized unless current_user

        comment = params[:comment] || ''

        if comment.blank?
          current_user.account_notes.find_by(target_actor: @account)&.destroy
        else
          note = current_user.account_notes.find_or_initialize_by(target_actor: @account)
          note.comment = comment

          return render json: { error: 'Failed to save note', details: note.errors.full_messages }, status: :unprocessable_entity unless note.save
        end

        render json: serialized_relationship(@account)
      end

      private

      def cannot_follow_self?
        @account == current_user
      end

      def render_follow_error
        render json: { error: 'Cannot follow yourself' }, status: :unprocessable_content
      end

      def find_existing_follow
        current_user.follows.find_by(target_actor: @account)
      end

      def render_existing_follow_response(existing_follow)
        log_existing_follow_status(existing_follow)
        render json: serialized_relationship(@account)
      end

      def log_existing_follow_status(existing_follow)
        if existing_follow.accepted?
          Rails.logger.info "Already following #{@account.ap_id}"
        else
          Rails.logger.info "Follow request already sent to #{@account.ap_id}"
        end
      end

      def create_new_follow
        follow_service = FollowService.new(current_user)
        follow = follow_service.follow!(@account)

        if follow
          Rails.logger.info "Follow request created for #{@account.ap_id}"
          render json: serialized_relationship(@account)
        else
          render json: { error: 'Follow failed', details: ['Could not create follow relationship'] }, status: :unprocessable_entity
        end
      end

      def render_follow_creation_error(follow)
        Rails.logger.error "Failed to create follow: #{follow.errors.full_messages}"
        render json: { error: 'Follow failed', details: follow.errors.full_messages }, status: :unprocessable_entity
      end

      def set_account
        @account = Actor.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Record not found' }, status: :not_found
      end

      def account_params
        params.permit(:display_name, :note, :locked, :bot, :discoverable, :avatar, :header,
                      fields_attributes: %i[name value])
      end

      # Active Storage版の画像アップロード処理
      def handle_avatar_upload_active_storage
        return unless valid_upload?(params[:avatar])

        current_user.avatar.attach(params[:avatar])
        Rails.logger.info "Avatar uploaded for #{current_user.username} via Active Storage"
      end

      def handle_header_upload_active_storage
        return unless valid_upload?(params[:header])

        current_user.header.attach(params[:header])
        Rails.logger.info "Header uploaded for #{current_user.username} via Active Storage"
      end

      def file_extension(filename)
        File.extname(filename).downcase.delete('.')
      end

      def render_unauthorized
        render json: { error: 'This action requires authentication' }, status: :unauthorized
      end

      def process_file_uploads
        handle_avatar_upload_active_storage if params[:avatar].present?
        handle_header_upload_active_storage if params[:header].present?
      end

      def update_account_attributes
        update_params = account_params.except(:avatar, :header, :fields_attributes)

        # fields_attributesをfieldsに変換
        if params.key?(:fields_attributes)
          fields = params[:fields_attributes].values.map do |field|
            {
              'name' => field[:name].to_s.strip,
              'value' => field[:value].to_s.strip
            }
          end.select { |field| field['name'].present? || field['value'].present? }
          update_params[:fields] = fields.to_json
        end

        if current_user.update(update_params)
          render json: serialized_account(current_user, is_self: true)
        else
          render_validation_error
        end
      end

      def render_validation_error
        render json: {
          error: 'Validation failed',
          details: current_user.errors.full_messages
        }, status: :unprocessable_entity
      end

      def valid_upload?(file)
        file&.respond_to?(:tempfile)
      end

      def serialized_relationship(account)
        return {} unless current_user

        {
          id: account.id.to_s,
          **follow_relationship_data(account),
          **blocking_relationship_data(account),
          **muting_relationship_data(account),
          **additional_relationship_data(account)
        }
      end

      def follow_relationship_data(account)
        following_relationship = Follow.find_by(actor: current_user, target_actor: account)
        followed_by_relationship = Follow.find_by(actor: account, target_actor: current_user)

        {
          following: following_relationship&.accepted? || false,
          followed_by: followed_by_relationship&.accepted? || false,
          showing_reblogs: true,
          notifying: false,
          requested: following_relationship&.pending? || false
        }
      end

      def blocking_relationship_data(account)
        {
          blocking: current_user.blocking?(account),
          blocked_by: current_user.blocked_by?(account),
          domain_blocking: account.domain.present? ? current_user.domain_blocking?(account.domain) : false
        }
      end

      def muting_relationship_data(account)
        mute = current_user.mutes.find_by(target_actor: account)
        {
          muting: current_user.muting?(account),
          muting_notifications: mute&.notifications || false
        }
      end

      def additional_relationship_data(account)
        note = current_user.account_notes.find_by(target_actor: account)
        {
          endorsed: false,
          note: note&.comment || ''
        }
      end

      def default_avatar_url
        '/icon.png'
      end

      def default_header_url
        '/icon.png'
      end

      def render_block_authentication_error
        render json: { error: 'This action requires authentication' }, status: :unauthorized
      end

      def render_block_self_error
        render json: { error: 'Cannot block yourself' }, status: :unprocessable_entity
      end

      def process_block_action
        # Remove any existing follow relationships (both directions)
        current_user.follows.find_by(target_actor: @account)&.destroy
        @account.follows.find_by(target_actor: current_user)&.destroy

        # Create block
        current_user.blocks.find_or_create_by(target_actor: @account)
      end

      def search_accounts(query, limit, resolve = false)
        # ローカル検索を実行
        local_accounts = Actor.where(
          'username LIKE ? OR display_name LIKE ?',
          "%#{query}%", "%#{query}%"
        ).limit(limit)

        # resolveがtrueで、ローカル結果が少ない場合はWebFinger解決を試行
        if resolve && local_accounts.count < limit && query.include?('@')
          remote_account = resolve_remote_account(query)
          local_accounts = [remote_account] + local_accounts.to_a if remote_account && local_accounts.exclude?(remote_account)
        end

        local_accounts
      end

      def lookup_account(acct)
        if acct.include?('@')
          username, domain = acct.split('@', 2)
          # まずローカルDBから検索
          actor = Actor.find_by(username: username, domain: domain)

          # 見つからない場合はWebFinger解決を試行
          actor ||= resolve_remote_account(acct)

          actor
        else
          Actor.find_by(username: acct, local: true)
        end
      end

      def resolve_remote_account(query)
        resolver = Search::RemoteResolverService.new
        resolver.resolve_remote_account(query)
      end

      def set_account_for_featured_tags
        @account = Actor.find(params[:id])
      end

      def serialized_featured_tag(featured_tag)
        {
          id: featured_tag.id.to_s,
          name: featured_tag.name,
          statuses_count: featured_tag.statuses_count,
          last_status_at: featured_tag.last_status_at&.iso8601
        }
      end

      def apply_timeline_pagination(query)
        query = query.where(objects: { id: ...(params[:max_id]) }) if params[:max_id].present?

        query = query.where('objects.id > ?', params[:since_id]) if params[:since_id].present?

        query = query.where('objects.id > ?', params[:min_id]) if params[:min_id].present?

        query
      end
    end
  end
end
