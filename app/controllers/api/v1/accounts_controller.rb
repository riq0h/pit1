# frozen_string_literal: true

module Api
  module V1
    class AccountsController < Api::BaseController
      include AccountSerializer
      before_action :doorkeeper_authorize!, except: [:show]
      before_action :doorkeeper_authorize!, only: [:show], if: -> { request.authorization.present? }
      before_action :set_account, except: %i[verify_credentials]

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
        return render json: { error: 'This action requires authentication' }, status: :unauthorized unless current_user

        if current_user.update(account_params)
          render json: serialized_account(current_user, is_self: true)
        else
          render json: { error: 'Validation failed', details: current_user.errors.full_messages },
                 status: :unprocessable_entity
        end
      end

      # GET /api/v1/accounts/:id/statuses
      def statuses
        statuses = @account.objects
                           .where(object_type: 'Note')
                           .where(local: true)
                           .order(published_at: :desc)
                           .limit(20)

        render json: statuses.map { |status| serialized_status(status) }
      end

      # GET /api/v1/accounts/:id/followers
      def followers
        followers = @account.followers.limit(40)
        render json: followers.map { |follower| serialized_account(follower) }
      end

      # GET /api/v1/accounts/:id/following
      def following
        following = @account.followed_actors.limit(40)
        render json: following.map { |followed| serialized_account(followed) }
      end

      # POST /api/v1/accounts/:id/follow
      def follow
        return render json: { error: 'Cannot follow yourself' }, status: :unprocessable_content if @account == current_user

        follow = current_user.follows.find_or_initialize_by(target_actor: @account)

        if follow.persisted? || follow.save
          render json: serialized_relationship(@account)
        else
          render json: { error: 'Follow failed' }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/accounts/:id/unfollow
      def unfollow
        follow = current_user.follows.find_by(target_actor: @account)
        follow&.destroy

        render json: serialized_relationship(@account)
      end

      # POST /api/v1/accounts/:id/block
      def block
        # TODO: Implement blocking functionality
        render json: serialized_relationship(@account)
      end

      # POST /api/v1/accounts/:id/unblock
      def unblock
        # TODO: Implement unblocking functionality
        render json: serialized_relationship(@account)
      end

      # POST /api/v1/accounts/:id/mute
      def mute
        # TODO: Implement muting functionality
        render json: serialized_relationship(@account)
      end

      # POST /api/v1/accounts/:id/unmute
      def unmute
        # TODO: Implement unmuting functionality
        render json: serialized_relationship(@account)
      end

      private

      def set_account
        @account = Actor.find(params[:id])
      end

      def account_params
        params.permit(:display_name, :summary, :locked, :bot, :discoverable)
      end

      def serialized_status(status)
        {
          id: status.id.to_s,
          created_at: status.published_at.iso8601,
          in_reply_to_id: nil,
          in_reply_to_account_id: nil,
          sensitive: status.sensitive || false,
          spoiler_text: status.summary || '',
          visibility: status.visibility || 'public',
          language: 'ja',
          uri: status.ap_id,
          url: status.public_url,
          replies_count: 0,
          reblogs_count: 0,
          favourites_count: 0,
          content: status.content || '',
          reblog: nil,
          account: serialized_account(status.actor),
          media_attachments: [],
          mentions: [],
          tags: [],
          emojis: [],
          card: nil,
          poll: nil
        }
      end

      def serialized_relationship(account)
        {
          id: account.id.to_s,
          following: current_user.followed_actors.include?(account),
          showing_reblogs: true,
          notifying: false,
          followed_by: account.followers.include?(current_user),
          blocking: false,
          blocked_by: false,
          muting: false,
          muting_notifications: false,
          requested: false,
          domain_blocking: false,
          endorsed: false
        }
      end

      def default_avatar_url
        '/icon.png'
      end

      def default_header_url
        '/icon.png'
      end
    end
  end
end
