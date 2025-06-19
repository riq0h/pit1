# frozen_string_literal: true

class FilterKeyword < ApplicationRecord
  belongs_to :filter

  validates :keyword, presence: true, length: { maximum: 200 }
  validates :filter_id, uniqueness: { scope: :keyword }
  validates :whole_word, inclusion: { in: [true, false] }

  scope :whole_word, -> { where(whole_word: true) }
  scope :partial, -> { where(whole_word: false) }
end