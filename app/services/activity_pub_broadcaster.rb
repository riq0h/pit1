# frozen_string_literal: true

class ActivityPubBroadcaster
  def initialize(object)
    @object = object
  end

  def broadcast_status_update
    return unless should_broadcast?

    # タイムラインストリーミング配信
    broadcast_to_timelines

    # 通知配信
    broadcast_notifications
  end

  def broadcast_status_delete
    return unless should_broadcast?

    ActionCable.server.broadcast(
      'timeline:public',
      {
        event: 'delete',
        payload: object.id.to_s
      }
    )

    # ユーザタイムラインからも削除通知
    object.actor.followers.find_each do |follower|
      ActionCable.server.broadcast(
        "timeline:#{follower.id}",
        {
          event: 'delete',
          payload: object.id.to_s
        }
      )
    end
  end

  private

  attr_reader :object

  def should_broadcast?
    object.local? && %w[public unlisted].include?(object.visibility)
  end

  def broadcast_to_timelines
    # パブリックタイムライン
    if object.visibility == 'public'
      ActionCable.server.broadcast(
        'timeline:public',
        {
          event: 'update',
          payload: serialized_object
        }
      )
    end

    # フォロワーのホームタイムライン
    object.actor.followers.find_each do |follower|
      ActionCable.server.broadcast(
        "timeline:#{follower.id}",
        {
          event: 'update',
          payload: serialized_object
        }
      )
    end
  end

  def broadcast_notifications
    # メンション通知
    object.mentions.includes(:actor).find_each do |mention|
      ActionCable.server.broadcast(
        "notifications:#{mention.actor.id}",
        {
          event: 'notification',
          payload: {
            id: SecureRandom.hex(8),
            type: 'mention',
            created_at: object.published_at.iso8601,
            account: simple_account_data(object.actor),
            status: serialized_object
          }
        }
      )
    end
  end

  def serialized_object
    # 簡略化されたオブジェクトシリアライゼーション
    {
      id: object.id.to_s,
      content: object.content,
      created_at: object.published_at.iso8601,
      account: simple_account_data(object.actor),
      visibility: object.visibility
    }
  end

  def simple_account_data(actor)
    {
      id: actor.id.to_s,
      username: actor.username,
      display_name: actor.display_name || actor.username,
      acct: actor.local? ? actor.username : actor.full_username
    }
  end
end
