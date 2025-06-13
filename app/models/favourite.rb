# frozen_string_literal: true

class Favourite < ApplicationRecord
  belongs_to :actor, class_name: 'Actor'
  belongs_to :object, class_name: 'ActivityPubObject'

  validates :actor_id, uniqueness: { scope: :object_id }

  after_create :increment_favourites_count
  after_destroy :decrement_favourites_count

  private

  def increment_favourites_count
    object.increment!(:favourites_count)
  end

  def decrement_favourites_count
    object.decrement!(:favourites_count)
  end
end
