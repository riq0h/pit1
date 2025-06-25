# frozen_string_literal: true

class SendPinnedStatusAddJob < ApplicationJob
  queue_as :default

  def perform(actor_id, object_id)
    actor = Actor.find(actor_id)
    object = ActivityPubObject.find(object_id)
    
    return unless actor.local?

    add_activity = build_add_activity(actor, object)
    distribute_activity(add_activity, actor)
  end

  private

  def build_add_activity(actor, object)
    {
      '@context' => 'https://www.w3.org/ns/activitystreams',
      'id' => "#{actor.ap_id}#add-#{object.id}-#{Time.current.to_i}",
      'type' => 'Add',
      'actor' => actor.ap_id,
      'object' => object.ap_id,
      'target' => "#{actor.ap_id}/collections/featured",
      'published' => Time.current.iso8601
    }
  end

  def distribute_activity(activity, actor)
    follower_inboxes = actor.followers.where(local: false).pluck(:shared_inbox_url, :inbox_url)
                           .map { |shared, inbox| shared.presence || inbox }
                           .compact.uniq

    follower_inboxes.each do |inbox_url|
      send_activity_to_inbox(activity, inbox_url, actor)
    end
  end

  def send_activity_to_inbox(activity, inbox_url, actor)
    activity_sender = ActivitySender.new
    
    success = activity_sender.send_activity(
      activity: activity,
      target_inbox: inbox_url,
      signing_actor: actor
    )
    
    if success
      Rails.logger.info "✅ Add activity sent successfully to #{inbox_url}"
    else
      Rails.logger.warn "❌ Failed to send Add activity to #{inbox_url}"
    end
    
    success
  rescue StandardError => e
    Rails.logger.error "💥 Error sending Add activity to #{inbox_url}: #{e.message}"
    false
  end
end