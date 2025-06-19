# frozen_string_literal: true

class Bookmark < ApplicationRecord
  belongs_to :actor
  belongs_to :object, class_name: 'ActivityPubObject'

  validates :actor_id, presence: true
  validates :object_id, presence: true
  validates :actor_id, uniqueness: { scope: :object_id }

  scope :recent, -> { order(created_at: :desc) }
end