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
    return false unless vapid_keys_configured?

    payload = subscription.push_payload(notification_type, title, body, options)
    send_push_notification(subscription, payload)
  end

  class << self
    private

    def vapid_keys_configured?
      unless vapid_public_key.present? && vapid_private_key.present?
        Rails.logger.warn '⚠️ VAPID keys not configured, skipping push notification'
        return false
      end
      true
    end

    def send_push_notification(subscription, payload)
      WebPush.payload_send(build_push_options(subscription, payload))
      true
    rescue WebPush::InvalidSubscription, WebPush::ExpiredSubscription => e
      handle_invalid_subscription(subscription, e)
    rescue StandardError => e
      handle_push_error(subscription, e)
    end

    def build_push_options(subscription, payload)
      {
        message: payload.to_json,
        endpoint: subscription.endpoint,
        p256dh: subscription.p256dh_key,
        auth: subscription.auth_key,
        vapid: build_vapid_options,
        ttl: 3600 * 24,
        urgency: 'normal'
      }
    end

    def build_vapid_options
      {
        subject: Rails.application.config.activitypub.base_url,
        public_key: vapid_public_key,
        private_key: vapid_private_key
      }
    end

    def handle_invalid_subscription(subscription, error)
      Rails.logger.warn "Invalid push subscription for #{subscription.actor.username}: #{error.message}"
      subscription.destroy
      false
    end

    def handle_push_error(subscription, error)
      Rails.logger.error "Push notification failed for #{subscription.actor.username}: #{error.message}"
      Rails.logger.error error.backtrace.join("\n") if Rails.env.development?
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
      '投票が終了しました',
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

  def self.notification_for_quote(quote_post, notification_id = nil)
    return unless quote_post.quoted_object.actor.local?

    send_notification(
      quote_post.quoted_object.actor,
      'quote',
      "#{quote_post.actor.display_name_or_username}さんがあなたの投稿を引用しました",
      strip_tags(quote_post.object.content || ''),
      {
        notification_id: notification_id,
        url: quote_post.object.ap_id,
        icon: quote_post.actor.avatar_url
      }
    )
  end

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
