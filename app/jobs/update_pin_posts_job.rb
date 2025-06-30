# frozen_string_literal: true

class UpdatePinPostsJob < ApplicationJob
  queue_as :default

  def perform(actor_id)
    actor = Actor.find(actor_id)
    return unless actor && !actor.local? && actor.featured_url.present?

    fetcher = FeaturedCollectionFetcher.new
    fetcher.fetch_for_actor(actor)
  rescue ActiveRecord::RecordNotFound
    Rails.logger.warn "⚠️ Actor #{actor_id} not found for pin posts update"
  rescue StandardError => e
    Rails.logger.error "❌ Failed to update pin posts for actor #{actor_id}: #{e.message}"
  end
end
