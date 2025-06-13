# frozen_string_literal: true

class Block < ApplicationRecord
  belongs_to :actor, class_name: 'Actor'
  belongs_to :target_actor, class_name: 'Actor'

  validates :actor_id, uniqueness: { scope: :target_actor_id }
  validate :cannot_block_self

  private

  def cannot_block_self
    errors.add(:target_actor, 'cannot block yourself') if actor_id == target_actor_id
  end
end
