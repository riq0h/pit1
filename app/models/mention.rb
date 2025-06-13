# frozen_string_literal: true

class Mention < ApplicationRecord
  belongs_to :object, class_name: 'ActivityPubObject'
  belongs_to :actor

  validates :acct, presence: true

  scope :local, -> { joins(:actor).where(actors: { local: true }) }
  scope :remote, -> { joins(:actor).where(actors: { local: false }) }
end
