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

  # 現在のユーザーの投票情報を含むPollデータをシリアライズ
  def serialize_poll_with_user_votes(poll, current_user = nil)
    data = serialize_poll_base(poll)
    return data unless data && current_user

    # ユーザーの投票情報を追加（poll_votesを使用）
    if poll.voted_by?(current_user)
      data[:voted] = true
      data[:own_votes] = poll.actor_choices(current_user)
    end

    data
  end

  # 検索結果用の簡略化されたPollデータをシリアライズ
  def serialize_poll_for_search(poll)
    serialize_poll_base(poll)
  end
end