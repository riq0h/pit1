# frozen_string_literal: true

class UpdatePinPostsJob < ApplicationJob
  queue_as :default

  def perform(actor_id)
    actor = Actor.find(actor_id)
    return unless actor && !actor.local? && actor.featured_url.present?

    Rails.logger.info "🔄 Background update of pin posts for #{actor.username}@#{actor.domain}"

    fetcher = FeaturedCollectionFetcher.new
    pinned_objects = fetcher.fetch_for_actor(actor)

    if pinned_objects.any?
      Rails.logger.info "✅ Updated #{pinned_objects.count} pin posts for #{actor.username}@#{actor.domain}"
    else
      Rails.logger.info "⚪ No pin posts found for #{actor.username}@#{actor.domain}"
    end
  rescue ActiveRecord::RecordNotFound
    Rails.logger.warn "⚠️ Actor #{actor_id} not found for pin posts update"
  rescue StandardError => e
    Rails.logger.error "❌ Failed to update pin posts for actor #{actor_id}: #{e.message}"
  end
end
