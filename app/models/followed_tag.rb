# frozen_string_literal: true

class FollowedTag < ApplicationRecord
  belongs_to :actor
  belongs_to :tag

  validates :actor_id, uniqueness: { scope: :tag_id }

  scope :recent, -> { order(created_at: :desc) }

  delegate :name, to: :tag
end