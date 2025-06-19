# frozen_string_literal: true

class FilterStatus < ApplicationRecord
  belongs_to :filter
  belongs_to :status, class_name: 'ActivityPubObject', foreign_key: :status_id, primary_key: :id

  validates :filter_id, uniqueness: { scope: :status_id }
  validates :status_id, presence: true
end