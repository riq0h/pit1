# frozen_string_literal: true

module FeaturedTagSerializer
  extend ActiveSupport::Concern

  private

  def serialized_featured_tag(featured_tag)
    {
      id: featured_tag.id.to_s,
      name: featured_tag.name,
      statuses_count: featured_tag.statuses_count,
      last_status_at: featured_tag.last_status_at&.iso8601
    }
  end
end
