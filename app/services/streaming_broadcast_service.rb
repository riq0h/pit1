# frozen_string_literal: true

class StreamingBroadcastService
  include ActionView::Helpers::SanitizeHelper

  def self.broadcast_status_update(status)
    new.broadcast_status_update(status)
  end

  def self.broadcast_status_delete(status_id)
    new.broadcast_status_delete(status_id)
  end

  def self.broadcast_notification(notification)
    new.broadcast_notification(notification)
  end

  def broadcast_status_update(status)
    return unless status.is_a?(ActivityPubObject) && status.object_type == 'Note'

    serialized_status = serialize_status(status)

    # パブリックタイムラインへの配信
    if status.visibility == 'public'
      ActionCable.server.broadcast('timeline:public', {
                                     event: 'update',
                                     payload: serialized_status
                                   })

      # ローカル投稿の場合はローカルタイムラインにも配信
      if status.local?
        ActionCable.server.broadcast('timeline:public:local', {
                                       event: 'update',
                                       payload: serialized_status
                                     })
      end

      # ハッシュタグストリームへの配信
      broadcast_to_hashtag_streams(status, serialized_status)
    end

    # ホームタイムラインへの配信
    broadcast_to_home_timelines(status, serialized_status)

    # リストタイムラインへの配信
    broadcast_to_list_timelines(status, serialized_status)
  end

  def broadcast_status_delete(status_id)
    delete_event = {
      event: 'delete',
      payload: status_id.to_s
    }

    # 全てのタイムラインに削除イベントをブロードキャスト
    ActionCable.server.broadcast('timeline:public', delete_event)
    ActionCable.server.broadcast('timeline:public:local', delete_event)
  end

  def broadcast_notification(notification)
    serialized_notification = serialize_notification(notification)

    ActionCable.server.broadcast("notifications:#{notification.account_id}", {
                                   event: 'notification',
                                   payload: serialized_notification
                                 })
  end

  private

  def broadcast_to_hashtag_streams(status, serialized_status)
    status.tags.each do |tag|
      hashtag_event = {
        event: 'update',
        payload: serialized_status
      }

      # グローバルハッシュタグストリーム
      ActionCable.server.broadcast("hashtag:#{tag.name.downcase}", hashtag_event)

      # ローカルハッシュタグストリーム（ローカル投稿のみ）
      ActionCable.server.broadcast("hashtag:#{tag.name.downcase}:local", hashtag_event) if status.local?
    end
  end

  def broadcast_to_home_timelines(status, serialized_status)
    # フォロワーのホームタイムラインに配信
    follower_ids = status.actor.followers.local.pluck(:id)

    follower_ids.each do |follower_id|
      ActionCable.server.broadcast("timeline:home:#{follower_id}", {
                                     event: 'update',
                                     payload: serialized_status
                                   })
    end

    # 自分のホームタイムラインにも配信
    return unless status.actor.local?

    ActionCable.server.broadcast("timeline:home:#{status.actor_id}", {
                                   event: 'update',
                                   payload: serialized_status
                                 })
  end

  def broadcast_to_list_timelines(status, serialized_status)
    # リストメンバーに含まれているかチェック
    list_memberships = ListMembership.joins(:list)
                                     .where(actor_id: status.actor_id)
                                     .includes(:list)

    list_memberships.each do |membership|
      ActionCable.server.broadcast("list:#{membership.list_id}", {
                                     event: 'update',
                                     payload: serialized_status
                                   })
    end
  end

  def serialize_status(status)
    {
      id: status.id.to_s,
      created_at: status.published_at&.iso8601,
      content: sanitize_content(status.content),
      content_plaintext: status.content_plaintext,
      summary: status.summary,
      sensitive: status.sensitive?,
      visibility: status.visibility,
      language: status.language,
      url: status.url,
      replies_count: status.replies_count,
      reblogs_count: status.reblogs_count,
      favourites_count: status.favourites_count,
      account: serialize_account(status.actor),
      media_attachments: serialize_media_attachments(status),
      mentions: serialize_mentions(status),
      tags: serialize_tags(status),
      emojis: []
    }
  end

  def serialize_account(actor)
    {
      id: actor.id.to_s,
      username: actor.username,
      acct: actor.acct,
      display_name: actor.display_name,
      locked: actor.locked?,
      bot: actor.bot?,
      discoverable: actor.discoverable?,
      note: sanitize_content(actor.note),
      url: actor.url,
      avatar: actor.avatar_url,
      header: actor.header_url,
      followers_count: actor.followers_count,
      following_count: actor.following_count,
      statuses_count: actor.posts_count,
      created_at: actor.created_at.iso8601
    }
  end

  def serialize_media_attachments(status)
    status.media_attachments.map do |media|
      {
        id: media.id.to_s,
        type: media.media_type,
        url: media.url,
        preview_url: media.preview_url,
        remote_url: media.remote_url,
        description: media.description,
        blurhash: media.blurhash,
        meta: build_media_meta(media)
      }
    end
  end

  def serialize_mentions(status)
    status.mentions.includes(:actor).map do |mention|
      {
        id: mention.actor.id.to_s,
        username: mention.actor.username,
        acct: mention.actor.acct,
        url: mention.actor.url
      }
    end
  end

  def serialize_tags(status)
    status.tags.map do |tag|
      {
        name: tag.name,
        url: "/tags/#{tag.name}"
      }
    end
  end

  def serialize_notification(notification)
    {
      id: notification.id.to_s,
      type: notification.notification_type,
      created_at: notification.created_at.iso8601,
      account: serialize_account(notification.from_actor)
    }
  end

  def build_media_meta(media)
    return {} unless media.width && media.height

    {
      original: {
        width: media.width,
        height: media.height,
        size: "#{media.width}x#{media.height}",
        aspect: (media.width.to_f / media.height).round(2)
      }
    }
  end

  def sanitize_content(content)
    return '' if content.blank?

    sanitize(content, tags: %w[p br strong em a span],
                      attributes: %w[href class])
  end
end
