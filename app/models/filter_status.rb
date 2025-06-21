# frozen_string_literal: true

class FilterStatus < ApplicationRecord
  belongs_to :filter
  belongs_to :status, class_name: 'ActivityPubObject', primary_key: :id

  validates :filter_id, uniqueness: { scope: :status_id }
end
