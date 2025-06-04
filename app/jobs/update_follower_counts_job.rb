# frozen_string_literal: true

class UpdateFollowerCountsJob < ApplicationJob
  queue_as :default

  def perform(actor_id, target_actor_id)
    actor = Actor.find_by(id: actor_id)
    target_actor = Actor.find_by(id: target_actor_id)

    actor&.update_following_count!
    target_actor&.update_followers_count!
  rescue StandardError => e
    Rails.logger.error "Failed to update follower counts: #{e.message}"
    raise
  end
end
