# frozen_string_literal: true

class WebPushSubscription < ApplicationRecord
  belongs_to :actor

  validates :endpoint, presence: true, uniqueness: { scope: :actor_id }
  validates :p256dh_key, presence: true
  validates :auth_key, presence: true

  scope :active, -> { where.not(endpoint: nil) }

  def data_hash
    JSON.parse(data || '{}')
  rescue JSON::ParserError
    {}
  end

  def data_hash=(hash)
    self.data = hash.to_json
  end

  def alerts
    data_hash['alerts'] || default_alerts
  end

  def alerts=(alert_hash)
    current_data = data_hash
    current_data['alerts'] = alert_hash
    self.data_hash = current_data
  end

  def default_alerts
    {
      'follow' => true,
      'follow_request' => true,
      'favourite' => true,
      'reblog' => true,
      'mention' => true,
      'poll' => true,
      'status' => false,
      'update' => false
    }
  end

  def push_payload(notification_type, title, body, options = {})
    # Mastodon公式アプリ用のペイロード形式
    if endpoint&.include?('app.joinmastodon.org')
      {
        access_token: Doorkeeper::AccessToken.where(resource_owner_id: actor.id, revoked_at: nil).last&.token,
        preferred_locale: 'ja',
        notification_id: options[:notification_id]&.to_s,
        notification_type: notification_type,
        title: title,
        body: body,
        icon: options[:icon] || default_icon
      }
    # FCM直接用のペイロード形式
    elsif endpoint&.include?('fcm.googleapis.com')
      {
        data: {
          notification_id: options[:notification_id]&.to_s,
          notification_type: notification_type,
          title: title,
          body: body,
          icon: options[:icon] || default_icon,
          url: options[:url],
          preferred_locale: 'ja'
        }
      }
    # 標準Web Push形式
    else
      {
        notification_id: options[:notification_id]&.to_s,
        notification_type: notification_type,
        title: title,
        body: body,
        icon: options[:icon] || default_icon,
        badge: options[:badge] || default_badge,
        tag: options[:tag] || notification_type,
        data: {
          url: options[:url],
          count: options[:count] || 1,
          preferred_locale: 'ja'
        }
      }
    end
  end

  def should_send_alert?(notification_type)
    alerts[notification_type.to_s] == true
  end

  private

  def default_icon
    "#{Rails.application.config.activitypub.base_url}/favicon.ico"
  end

  def default_badge
    "#{Rails.application.config.activitypub.base_url}/favicon.ico"
  end
end
