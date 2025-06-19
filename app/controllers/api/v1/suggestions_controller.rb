# frozen_string_literal: true

module Api
  module V1
    class SuggestionsController < Api::BaseController
      before_action :doorkeeper_authorize!
      before_action :require_user!

      # GET /api/v1/suggestions
      def index
        limit = [params[:limit].to_i, 40].min
        limit = 20 if limit <= 0

        suggestions = generate_suggestions(limit)
        render json: suggestions.map { |actor| serialized_suggestion(actor) }
      end

      # DELETE /api/v1/suggestions/:id
      def destroy
        # Letterでは推奨機能のカスタマイズは簡素化
        # 削除リクエストは受け入れるが、実際の処理は行わない
        render json: {}
      end

      private

      def generate_suggestions(limit)
        # Letterでは2ユーザ制限なので、ローカルアカウントは推奨対象外
        # 既にフォローしていないリモートユーザから推奨
        already_following_ids = current_user.following.pluck(:id)

        suggested_actors = Actor.remote
                                .where.not(id: already_following_ids)
                                .where('followers_count > ?', 0) # ある程度人気のあるアカウント
                                .order('followers_count DESC, created_at DESC')
                                .limit(limit)

        suggested_actors
      end

      def serialized_suggestion(actor)
        {
          source: 'featured', # Mastodon互換の推奨理由
          account: serialized_account(actor)
        }
      end

      def serialized_account(actor)
        {
          id: actor.id.to_s,
          username: actor.username,
          acct: actor.acct,
          display_name: actor.display_name_or_username,
          locked: actor.manually_approves_followers,
          bot: false,
          discoverable: actor.discoverable,
          group: false,
          created_at: actor.created_at&.iso8601,
          note: actor.note || '',
          url: actor.public_url,
          avatar: actor.avatar_url,
          avatar_static: actor.avatar_url,
          header: actor.header_image_url,
          header_static: actor.header_image_url,
          followers_count: actor.followers_count || 0,
          following_count: actor.following_count || 0,
          statuses_count: actor.posts_count || 0,
          last_status_at: nil,
          emojis: [],
          fields: []
        }
      end
    end
  end
end