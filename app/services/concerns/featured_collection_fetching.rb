# frozen_string_literal: true

module FeaturedCollectionFetching
  extend ActiveSupport::Concern

  private

  def fetch_featured_collection_async(actor)
    return if actor.featured_url.blank?

    # Featured Collection を非同期で取得
    FeaturedCollectionFetcher.new.fetch_for_actor(actor)
  rescue StandardError => e
    Rails.logger.error "Failed to fetch featured collection for #{actor.username}@#{actor.domain}: #{e.message}"
  end
end
