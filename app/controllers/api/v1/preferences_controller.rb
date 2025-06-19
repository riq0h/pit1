# frozen_string_literal: true

module Api
  module V1
    class PreferencesController < Api::BaseController
      before_action :doorkeeper_authorize!
      before_action :require_user!

      # GET /api/v1/preferences
      def show
        # TODO: ユーザー設定機能の実装
        # Letterでは現在詳細な設定機能は未実装のため、デフォルト値を返す
        render json: default_preferences
      end

      private

      def default_preferences
        {
          'posting:default:visibility' => 'public',
          'posting:default:sensitive' => false,
          'posting:default:language' => 'ja',
          'reading:expand:media' => 'default',
          'reading:expand:spoilers' => false,
          'reading:autoplay:gifs' => true,
          'web:advanced_layout' => false,
          'web:use_blurhash' => true,
          'web:use_pending_items' => false,
          'web:trends' => true,
          'notification_emails' => {
            'follow' => true,
            'reblog' => true,
            'favourite' => true,
            'mention' => true,
            'follow_request' => true,
            'digest' => true
          }
        }
      end
    end
  end
end