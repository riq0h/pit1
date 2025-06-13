# frozen_string_literal: true

class Mute < ApplicationRecord
  belongs_to :actor, class_name: 'Actor'
  belongs_to :target_actor, class_name: 'Actor'

  validates :actor_id, uniqueness: { scope: :target_actor_id }
  validate :cannot_mute_self

  private

  def cannot_mute_self
    errors.add(:target_actor, 'cannot mute yourself') if actor_id == target_actor_id
  end
end
