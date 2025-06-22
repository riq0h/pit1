# frozen_string_literal: true

class RelayFollowService
  include ActivityPubHelper

  def call(relay)
    @relay = relay
    @local_actor = get_local_actor

    return false unless @local_actor && @relay&.idle?

    begin
      # リレーアクターの情報を取得
      relay_actor_data = fetch_activitypub_object(@relay.actor_uri)
      return false unless relay_actor_data

      # Follow アクティビティを作成
      follow_activity = create_follow_activity(relay_actor_data)

      # Follow アクティビティを送信
      success = deliver_activity(follow_activity, @relay.inbox_url)

      if success
        @relay.update!(
          state: 'pending',
          follow_activity_id: follow_activity['id'],
          followed_at: Time.current,
          last_error: nil
        )
        true
      else
        @relay.update!(last_error: 'Follow アクティビティの送信に失敗しました')
        false
      end
    rescue StandardError => e
      Rails.logger.error "Relay follow error: #{e.message}"
      @relay.update!(last_error: e.message)
      false
    end
  end

  private

  def get_local_actor
    # ローカルの管理者アカウントを取得
    actor = Actor.where(local: true, admin: true).first || Actor.where(local: true).first

    # ap_idが設定されていない場合は設定
    if actor && actor.ap_id.blank?
      actor.send(:set_ap_urls)
      actor.save!
    end

    actor
  end

  def create_follow_activity(relay_actor_data)
    activity_id = "#{@local_actor.ap_id}#follows/relay/#{SecureRandom.uuid}"

    {
      '@context' => 'https://www.w3.org/ns/activitystreams',
      'id' => activity_id,
      'type' => 'Follow',
      'actor' => @local_actor.ap_id,
      'object' => 'https://www.w3.org/ns/activitystreams#Public',
      'to' => ['https://www.w3.org/ns/activitystreams#Public']
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
    Rails.logger.error "Failed to deliver Follow activity: #{e.message}"
    false
  end
end
