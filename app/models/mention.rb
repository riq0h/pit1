# frozen_string_literal: true

class Mention < ApplicationRecord
  belongs_to :object, class_name: 'ActivityPubObject'
  belongs_to :actor

  validates :ap_id, presence: true

  before_validation :set_ap_id, on: :create

  scope :local, -> { joins(:actor).where(actors: { local: true }) }
  scope :remote, -> { joins(:actor).where(actors: { local: false }) }

  # Mastodon API互換のacct形式を返す
  def acct
    if actor.local?
      actor.username
    else
      "#{actor.username}@#{actor.domain}"
    end
  end

  private

  def set_ap_id
    return if ap_id.present?

    snowflake_id = Letter::Snowflake.generate
    self.ap_id = "#{Rails.application.config.activitypub.base_url}/#{snowflake_id}"
  end
end
