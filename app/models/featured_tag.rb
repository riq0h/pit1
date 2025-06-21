# frozen_string_literal: true

class FeaturedTag < ApplicationRecord
  belongs_to :actor
  belongs_to :tag

  validates :actor_id, uniqueness: { scope: :tag_id }

  scope :recent, -> { order(updated_at: :desc) }

  def increment_status_count!
    increment!(:statuses_count)
    update!(last_status_at: Time.current)
  end

  def decrement_status_count!
    decrement!(:statuses_count) if statuses_count.positive?
  end

  delegate :name, to: :tag
end
