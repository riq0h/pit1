# frozen_string_literal: true

class WebPushNotificationService
  def self.send_notification(actor, notification_type, title, body, options = {})
    return unless actor&.web_push_subscriptions&.any?

    actor.web_push_subscriptions.active.find_each do |subscription|
      next unless subscription.should_send_alert?(notification_type)

      SendWebPushNotificationJob.perform_later(subscription.id, notification_type, title, body, options)
    end
  end

  def self.send_to_subscription(subscription, notification_type, title, body, options = {})
    payload = subscription.push_payload(notification_type, title, body, options)

    Rails.logger.info "📱 Sending push notification for #{subscription.actor.username}: #{payload.to_json}"

    begin
      WebPush.payload_send(
        message: payload.to_json,
        endpoint: subscription.endpoint,
        p256dh: subscription.p256dh_key,
        auth: subscription.auth_key,
        vapid: {
          subject: Rails.application.config.activitypub.base_url,
          public_key: vapid_public_key,
          private_key: vapid_private_key
        },
        ttl: 3600 * 24,
        urgency: 'normal'
      )
      Rails.logger.info "✅ Push notification sent successfully to #{subscription.endpoint[0..50]}..."
      true
    rescue WebPush::InvalidSubscription, WebPush::ExpiredSubscription => e
      Rails.logger.warn "Invalid push subscription for #{subscription.actor.username}: #{e.message}"
      subscription.destroy
      false
    rescue StandardError => e
      Rails.logger.error "Push notification failed for #{subscription.actor.username}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n") if Rails.env.development?
      false
    end
  end

  def self.notification_for_follow(follower, target, notification_id = nil)
    return unless target.local?

    send_notification(
      target,
      'follow',
      "#{follower.display_name_or_username}さんがあなたをフォローしました",
      follower.note.present? ? strip_tags(follower.note) : '',
      {
        notification_id: notification_id,
        url: "#{Rails.application.config.activitypub.base_url}/@#{follower.username}",
        icon: follower.avatar_url
      }
    )
  end

  def self.notification_for_mention(status, mentioned_actor, notification_id = nil)
    return unless mentioned_actor.local?

    send_notification(
      mentioned_actor,
      'mention',
      "#{status.actor.display_name_or_username}さんからメンション",
      strip_tags(status.content || ''),
      {
        notification_id: notification_id,
        url: status.ap_id,
        icon: status.actor.avatar_url
      }
    )
  end

  def self.notification_for_favourite(favourite, notification_id = nil)
    return unless favourite.object.actor.local?

    send_notification(
      favourite.object.actor,
      'favourite',
      "#{favourite.actor.display_name_or_username}さんがいいねしました",
      strip_tags(favourite.object.content || ''),
      {
        notification_id: notification_id,
        url: favourite.object.ap_id,
        icon: favourite.actor.avatar_url
      }
    )
  end

  def self.notification_for_reblog(reblog, notification_id = nil)
    return unless reblog.object.actor.local?

    send_notification(
      reblog.object.actor,
      'reblog',
      "#{reblog.actor.display_name_or_username}さんがリブログしました",
      strip_tags(reblog.object.content || ''),
      {
        notification_id: notification_id,
        url: reblog.object.ap_id,
        icon: reblog.actor.avatar_url
      }
    )
  end

  def self.notification_for_follow_request(follower, target, notification_id = nil)
    return unless target.local?

    send_notification(
      target,
      'follow_request',
      "#{follower.display_name_or_username}さんからフォローリクエスト",
      follower.note.present? ? strip_tags(follower.note) : '',
      {
        notification_id: notification_id,
        url: "#{Rails.application.config.activitypub.base_url}/@#{follower.username}",
        icon: follower.avatar_url
      }
    )
  end

  def self.notification_for_poll(status, account, notification_id = nil)
    return unless account.local?

    send_notification(
      account,
      'poll',
      "投票が終了しました",
      strip_tags(status.content || ''),
      {
        notification_id: notification_id,
        url: status.ap_id,
        icon: status.actor.avatar_url
      }
    )
  end

  def self.notification_for_status(status, account, notification_id = nil)
    return unless account.local?

    send_notification(
      account,
      'status',
      "#{status.actor.display_name_or_username}さんが投稿しました",
      strip_tags(status.content || ''),
      {
        notification_id: notification_id,
        url: status.ap_id,
        icon: status.actor.avatar_url
      }
    )
  end

  def self.notification_for_update(status, account, notification_id = nil)
    return unless account.local?

    send_notification(
      account,
      'update',
      "#{status.actor.display_name_or_username}さんが投稿を編集しました",
      strip_tags(status.content || ''),
      {
        notification_id: notification_id,
        url: status.ap_id,
        icon: status.actor.avatar_url
      }
    )
  end

  private

  def self.strip_tags(html)
    return '' if html.blank?

    # HTMLタグを除去してプレーンテキストに変換
    html.gsub(/<[^>]*>/, '').strip.truncate(100)
  end

  def self.vapid_public_key
    ENV['VAPID_PUBLIC_KEY'] || Rails.application.credentials.dig(:vapid, :public_key)
  end

  def self.vapid_private_key
    ENV['VAPID_PRIVATE_KEY'] || Rails.application.credentials.dig(:vapid, :private_key)
  end
end
