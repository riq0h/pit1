# frozen_string_literal: true

class Notification < ApplicationRecord
  # アソシエーション
  belongs_to :account, class_name: 'Actor', inverse_of: :notifications
  belongs_to :from_account, class_name: 'Actor', inverse_of: :sent_notifications

  # ポリモーフィック関連（activity_type + activity_id）
  def activity
    return nil unless activity_type && activity_id

    case activity_type
    when 'Follow'
      Follow.find_by(id: activity_id)
    when 'ActivityPubObject'
      ActivityPubObject.find_by(id: activity_id)
    end
  end

  # 通知タイプの定義
  TYPES = %w[
    mention
    status
    reblog
    follow
    follow_request
    favourite
    poll
    update
  ].freeze

  # バリデーション
  validates :notification_type, inclusion: { in: TYPES }
  validates :activity_type, presence: true
  validates :activity_id, presence: true

  # コールバック
  after_create :send_push_notification
  after_create :broadcast_notification

  # スコープ
  scope :unread, -> { where(read: false) }
  scope :recent, -> { order(created_at: :desc) }
  scope :for_account, ->(account) { where(account: account) }
  scope :of_type, ->(type) { where(notification_type: type) }

  # 既読にする
  def mark_as_read!
    update!(read: true)
  end

  # 通知作成のクラスメソッド
  def self.create_follow_notification(follow)
    create!(
      account: follow.target_actor,
      from_account: follow.actor,
      activity_type: 'Follow',
      activity_id: follow.id.to_s,
      notification_type: 'follow'
    )
  end

  def self.create_follow_request_notification(follow)
    create!(
      account: follow.target_actor,
      from_account: follow.actor,
      activity_type: 'Follow',
      activity_id: follow.id.to_s,
      notification_type: 'follow_request'
    )
  end

  def self.create_mention_notification(mention, status)
    create!(
      account: mention.actor,
      from_account: status.actor,
      activity_type: 'ActivityPubObject',
      activity_id: status.id.to_s,
      notification_type: 'mention'
    )
  end

  def self.create_favourite_notification(favourite, status)
    create!(
      account: status.actor,
      from_account: favourite.actor,
      activity_type: 'ActivityPubObject',
      activity_id: status.id.to_s,
      notification_type: 'favourite'
    )
  end

  def self.create_reblog_notification(reblog, original_status)
    create!(
      account: original_status.actor,
      from_account: reblog.actor,
      activity_type: 'ActivityPubObject',
      activity_id: original_status.id.to_s,
      notification_type: 'reblog'
    )
  end

  private

  def send_push_notification
    case notification_type
    when 'follow'
      WebPushNotificationService.notification_for_follow(from_account, account, id)
    when 'follow_request'
      WebPushNotificationService.notification_for_follow_request(from_account, account, id)
    when 'mention'
      status = activity
      WebPushNotificationService.notification_for_mention(status, account, id) if status
    when 'favourite'
      status = activity
      favourite = Favourite.find_by(actor: from_account, object: status)
      WebPushNotificationService.notification_for_favourite(favourite, id) if favourite && status
    when 'reblog'
      status = activity
      reblog = Reblog.find_by(actor: from_account, object: status)
      WebPushNotificationService.notification_for_reblog(reblog, id) if reblog && status
    when 'poll'
      status = activity
      WebPushNotificationService.notification_for_poll(status, account, id) if status
    when 'status'
      status = activity
      WebPushNotificationService.notification_for_status(status, account, id) if status
    when 'update'
      status = activity
      WebPushNotificationService.notification_for_update(status, account, id) if status
    end
  rescue StandardError => e
    Rails.logger.error "Failed to send push notification: #{e.message}"
  end

  def broadcast_notification
    StreamingBroadcastService.broadcast_notification(self)
  rescue StandardError => e
    Rails.logger.error "💥 Notification broadcast error: #{e.message}"
  end
end
