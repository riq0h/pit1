# frozen_string_literal: true

module ActivityPub
  # ActivityPub基底例外
  class Error < StandardError; end

  # バリデーションエラー
  class ValidationError < Error; end

  # HTTP署名エラー
  class SignatureError < Error; end

  # ネットワークエラー
  class NetworkError < Error; end

  # アクター取得エラー
  class ActorFetchError < Error; end

  # JSONパースエラー
  class ParseError < Error; end

  # 権限エラー
  class AuthorizationError < Error; end

  # レート制限エラー
  class RateLimitError < Error; end
end

# Mastodon API互換例外
module Mastodon
  class Error < StandardError; end
  class ValidationError < Error; end
  class RateLimitExceededError < Error; end
  class NotPermittedError < Error; end
  class UnexpectedResponseError < Error; end
end
