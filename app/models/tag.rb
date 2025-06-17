# frozen_string_literal: true

class Tag < ApplicationRecord
  has_many :object_tags, dependent: :destroy
  has_many :objects, through: :object_tags, class_name: 'ActivityPubObject'

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :name, format: { with: /\A[a-zA-Z0-9_\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FAF]+\z/ }

  before_validation :normalize_name

  scope :trending, -> { where(trending: true) }
  scope :popular, -> { order(usage_count: :desc) }
  scope :recent, -> { order(updated_at: :desc) }

  def to_param
    name
  end

  def increment_usage!
    increment!(:usage_count)
    touch
  end

  def decrement_usage!
    decrement!(:usage_count)
  end

  private

  def normalize_name
    self.name = name.strip.downcase if name.present?
  end
end
