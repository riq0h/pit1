# frozen_string_literal: true

module PushPayloadBuilder
  extend ActiveSupport::Concern

  def build_push_payload(notification_type, title, body, options = {})
    base_payload = {
      title: title,
      body: body,
      icon: options[:icon] || '/icon.png',
      badge: '/badge.png',
      tag: notification_type,
      timestamp: Time.current.to_i * 1000,
      requireInteraction: should_require_interaction?(notification_type),
      actions: build_notification_actions(notification_type),
      data: build_notification_data(notification_type, options)
    }

    apply_platform_specific_settings(base_payload, notification_type)
  end

  private

  def should_require_interaction?(notification_type)
    %w[follow follow_request mention].include?(notification_type)
  end

  def build_notification_actions(notification_type)
    case notification_type
    when 'mention', 'favourite', 'reblog'
      [
        { action: 'reply', title: '返信', icon: '/icons/reply.png' },
        { action: 'view', title: '表示', icon: '/icons/view.png' }
      ]
    when 'follow', 'follow_request'
      [
        { action: 'view_profile', title: 'プロフィール表示', icon: '/icons/profile.png' }
      ]
    else
      []
    end
  end

  def build_notification_data(notification_type, options)
    {
      type: notification_type,
      url: options[:url] || '/',
      notification_id: options[:notification_id],
      timestamp: Time.current.iso8601
    }.compact
  end

  def apply_platform_specific_settings(payload, notification_type)
    # Android固有の設定
    payload[:android] = {
      priority: notification_priority(notification_type),
      vibrate: vibration_pattern(notification_type),
      sound: 'default'
    }

    # iOS固有の設定
    payload[:apns] = {
      sound: 'default',
      badge: 1
    }

    payload
  end

  def notification_priority(notification_type)
    %w[mention follow_request].include?(notification_type) ? 'high' : 'normal'
  end

  def vibration_pattern(notification_type)
    case notification_type
    when 'mention'
      [200, 100, 200]
    when 'follow', 'follow_request'
      [100, 50, 100, 50, 100]
    else
      [100]
    end
  end
end
