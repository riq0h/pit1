# frozen_string_literal: true

class Favourite < ApplicationRecord
  belongs_to :actor, class_name: 'Actor'
  belongs_to :object, class_name: 'ActivityPubObject'

  validates :actor_id, uniqueness: { scope: :object_id }

  before_validation :set_ap_id, on: :create
  after_create :increment_favourites_count
  after_destroy :decrement_favourites_count

  private

  def set_ap_id
    return if ap_id.present?

    snowflake_id = Letter::Snowflake.generate
    self.ap_id = "#{Rails.application.config.activitypub.base_url}/#{snowflake_id}"
  end

  def increment_favourites_count
    object.increment!(:favourites_count)
  end

  def decrement_favourites_count
    object.decrement!(:favourites_count)
  end
end
