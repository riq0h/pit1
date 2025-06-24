# frozen_string_literal: true

module PollSerializer
  extend ActiveSupport::Concern

  private

  # 基本的なPollデータをシリアライズ
  def serialize_poll_base(poll)
    return nil unless poll.present?

    # Pollモデルの既存メソッドを活用
    poll.to_mastodon_api
  end

  # 検索結果用の簡略化されたPollデータをシリアライズ
  def serialize_poll_for_search(poll)
    serialize_poll_base(poll)
  end
end