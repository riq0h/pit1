# frozen_string_literal: true

class Mention < ApplicationRecord
  belongs_to :object, class_name: 'ActivityPubObject'
  belongs_to :actor

  validates :ap_id, presence: true

  before_validation :set_ap_id, on: :create
  after_create :create_notification

  scope :local, -> { joins(:actor).where(actors: { local: true }) }
  scope :remote, -> { joins(:actor).where(actors: { local: false }) }

  # Mastodon API互換のacct形式を返す
  def acct
    if actor.local?
      actor.username
    else
      "#{actor.username}@#{actor.domain}"
    end
  end

  private

  def set_ap_id
    return if ap_id.present?

    snowflake_id = Letter::Snowflake.generate
    self.ap_id = "#{Rails.application.config.activitypub.base_url}/#{snowflake_id}"
  end

  def create_notification
    # ローカルアクターへのメンション時のみ通知を作成
    return unless actor.local?

    # オブジェクト（投稿）の作成者と同じ場合は通知しない（自分への言及）
    return if actor == object.actor

    # 重複通知を防ぐためのチェック
    existing_notification = Notification.exists?(account: actor,
                                                 from_account: object.actor,
                                                 activity_type: 'ActivityPubObject',
                                                 activity_id: object.id.to_s,
                                                 notification_type: 'mention')

    return if existing_notification

    # メンション通知を作成
    Notification.create_mention_notification(self, object)
  rescue StandardError => e
    Rails.logger.error "Failed to create mention notification: #{e.message}"
  end
end
