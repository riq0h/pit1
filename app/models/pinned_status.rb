# frozen_string_literal: true

class PinnedStatus < ApplicationRecord
  belongs_to :actor
  belongs_to :object, class_name: 'ActivityPubObject', primary_key: :id

  validates :actor_id, uniqueness: { scope: :object_id }
  validates :position, presence: true, numericality: { greater_than_or_equal_to: 0 }

  scope :ordered, -> { order(position: :desc) }

  before_create :set_position
  after_create :send_add_activity, if: -> { actor.local? }
  after_destroy :send_remove_activity, if: -> { actor.local? }

  private

  def set_position
    return if position.present?

    max_position = actor.pinned_statuses.maximum(:position) || -1
    self.position = max_position + 1
  end

  def send_add_activity
    SendPinnedStatusAddJob.perform_later(actor.id, object.id)
  end

  def send_remove_activity
    SendPinnedStatusRemoveJob.perform_later(actor.id, object.id)
  end
end
