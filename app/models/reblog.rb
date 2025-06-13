# frozen_string_literal: true

class Reblog < ApplicationRecord
  belongs_to :actor, class_name: 'Actor'
  belongs_to :object, class_name: 'ActivityPubObject'

  validates :actor_id, uniqueness: { scope: :object_id }

  after_create :increment_reblogs_count
  after_destroy :decrement_reblogs_count

  private

  def increment_reblogs_count
    object.increment!(:reblogs_count)
  end

  def decrement_reblogs_count
    object.decrement!(:reblogs_count)
  end
end
