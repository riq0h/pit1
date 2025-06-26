# frozen_string_literal: true

# Mastodonの UpdateDistributionWorker を参考にした実装
class SendProfileUpdateJob < ApplicationJob
  queue_as :push

  def perform(actor_id)
    actor = Actor.find_by(id: actor_id)
    return if actor.nil? || !actor.local?

    # Updateアクティビティを構築
    update_activity = build_update_activity(actor)

    # フォロワーの inbox を収集（重複を排除）
    inboxes = collect_follower_inboxes(actor)

    # 各inboxに直接送信
    inboxes.each do |inbox_url|
      send_update_activity(update_activity, inbox_url, actor)
    end

    Rails.logger.info "Distributed profile update for @#{actor.username} to #{inboxes.size} inboxes"
  end

  private

  def build_update_activity(actor)
    {
      '@context': 'https://www.w3.org/ns/activitystreams',
      id: "#{actor.ap_id}#updates/#{Time.now.to_i}",
      type: 'Update',
      actor: actor.ap_id,
      to: ['https://www.w3.org/ns/activitystreams#Public'],
      object: actor.to_activitypub
    }
  end

  def collect_follower_inboxes(actor)
    # フォロワーのinboxを収集し、重複を排除
    inboxes = Set.new

    actor.followers.where.not(inbox_url: nil).find_each do |follower|
      # shared inbox の情報は raw_data から取得
      if follower.raw_data.present?
        begin
          raw_data = JSON.parse(follower.raw_data)
          shared_inbox = raw_data.dig('endpoints', 'sharedInbox')

          if shared_inbox.present?
            inboxes.add(shared_inbox)
          else
            inboxes.add(follower.inbox_url)
          end
        rescue JSON::ParserError
          # パースエラーの場合は通常のinboxを使用
          inboxes.add(follower.inbox_url)
        end
      else
        inboxes.add(follower.inbox_url)
      end
    end

    inboxes.to_a
  end

  def send_update_activity(update_activity, inbox_url, actor)
    activity_sender = ActivitySender.new

    result = activity_sender.send_activity(
      activity: update_activity,
      target_inbox: inbox_url,
      signing_actor: actor
    )

    success = result.is_a?(Hash) ? result[:success] : result

    if success
      Rails.logger.info "✅ Profile update sent successfully to #{inbox_url}"
    else
      error_msg = result.is_a?(Hash) ? result[:error] : 'Unknown error'
      Rails.logger.warn "❌ Failed to send profile update to #{inbox_url}: #{error_msg}"
    end

    success
  rescue StandardError => e
    Rails.logger.error "💥 Error sending profile update to #{inbox_url}: #{e.message}"
    false
  end
end
