# frozen_string_literal: true

module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    private

    def find_verified_user
      # OAuth トークンからユーザを認証
      token = request.params[:access_token]
      return reject_unauthorized_connection unless token

      # Doorkeeper のアクセストークンを検証
      access_token = Doorkeeper::AccessToken.by_token(token)
      return reject_unauthorized_connection unless access_token&.acceptable?

      # ユーザを取得
      user = Actor.find_by(id: access_token.resource_owner_id)
      return reject_unauthorized_connection unless user&.local?

      user
    rescue StandardError
      reject_unauthorized_connection
    end
  end
end
