# frozen_string_literal: true

class RelayUnfollowService
  include ActivityPubHelper

  def call(relay)
    @relay = relay
    @local_actor = get_local_actor

    return false unless @local_actor && @relay&.accepted?

    begin
      # リレーアクターの情報を取得
      relay_actor_data = fetch_activitypub_object(@relay.actor_uri)
      return false unless relay_actor_data

      # Undo Follow アクティビティを作成
      undo_activity = create_undo_activity(relay_actor_data)

      # Undo アクティビティを送信
      success = deliver_activity(undo_activity, @relay.inbox_url)

      if success
        @relay.update!(
          state: 'idle',
          follow_activity_id: nil,
          followed_at: nil,
          last_error: nil
        )
        true
      else
        @relay.update!(last_error: 'Undo Follow アクティビティの送信に失敗しました')
        false
      end
    rescue StandardError => e
      Rails.logger.error "Relay unfollow error: #{e.message}"
      @relay.update!(last_error: e.message)
      false
    end
  end

  private

  def get_local_actor
    # ローカルの管理者アカウントを取得
    Actor.where(local: true, admin: true).first || Actor.where(local: true).first
  end

  def create_undo_activity(relay_actor_data)
    undo_id = "#{@local_actor.ap_id}#follows/relay/undo/#{SecureRandom.uuid}"

    # 元のFollow アクティビティを再構築
    original_follow = {
      'id' => @relay.follow_activity_id,
      'type' => 'Follow',
      'actor' => @local_actor.ap_id,
      'object' => 'https://www.w3.org/ns/activitystreams#Public'
    }

    {
      '@context' => 'https://www.w3.org/ns/activitystreams',
      'id' => undo_id,
      'type' => 'Undo',
      'actor' => @local_actor.ap_id,
      'object' => original_follow,
      'to' => ['https://www.w3.org/ns/activitystreams#Public'],
      'cc' => []
    }
  end

  def deliver_activity(activity, inbox_url)
    activity_sender = ActivitySender.new
    activity_sender.send_activity(
      activity: activity,
      target_inbox: inbox_url,
      signing_actor: @local_actor
    )
  rescue StandardError => e
    Rails.logger.error "Failed to deliver Undo activity: #{e.message}"
    false
  end
end
