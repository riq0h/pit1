# frozen_string_literal: true

class Poll < ApplicationRecord
  belongs_to :object, class_name: 'ActivityPubObject', foreign_key: :object_id, primary_key: :id
  has_many :poll_votes, dependent: :destroy
  has_many :voters, through: :poll_votes, source: :actor

  validates :object_id, presence: true
  validates :expires_at, presence: true
  validates :options, presence: true
  validate :validate_options_format
  validate :validate_expiry_time
  validate :validate_not_expired_on_create, on: :create

  scope :expired, -> { where('expires_at < ?', Time.current) }
  scope :active, -> { where('expires_at >= ?', Time.current) }

  before_save :calculate_vote_counts

  def expired?
    expires_at < Time.current
  end

  def active?
    !expired?
  end

  def option_titles
    return [] unless options.is_a?(Array)

    options.map { |option| option['title'] || option[:title] }.compact
  end

  def option_votes_count(index)
    return 0 unless options.is_a?(Array) && index < options.length

    poll_votes.where(choice: index).count
  end

  def vote_for!(actor, choices)
    return false if expired?

    choices = Array(choices)
    return false if choices.empty?
    return false if !multiple && choices.length > 1
    return false if choices.any? { |choice| choice < 0 || choice >= options.length }

    ActiveRecord::Base.transaction do
      # 既存の投票を削除（単一選択の場合、または複数選択で全て再投票する場合）
      poll_votes.where(actor: actor).destroy_all

      # 新しい投票を追加
      choices.each do |choice|
        poll_votes.create!(actor: actor, choice: choice)
      end

      calculate_vote_counts
      save!
    end

    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  def voted_by?(actor)
    poll_votes.exists?(actor: actor)
  end

  def actor_choices(actor)
    poll_votes.where(actor: actor).pluck(:choice)
  end

  def to_mastodon_api
    {
      id: id.to_s,
      expires_at: expires_at.iso8601,
      expired: expired?,
      multiple: multiple,
      votes_count: votes_count,
      voters_count: multiple ? voters_count : votes_count,
      options: serialize_options,
      emojis: [],
      voted: false, # Will be set by controller based on current user
      own_votes: [] # Will be set by controller based on current user
    }
  end

  private

  def validate_options_format
    return unless options

    unless options.is_a?(Array) && options.length.between?(2, 4)
      errors.add(:options, 'must be an array with 2-4 options')
      return
    end

    options.each_with_index do |option, index|
      unless option.is_a?(Hash) && option['title'].present?
        errors.add(:options, "option #{index + 1} must have a title")
      end

      if option['title'].to_s.length > 50
        errors.add(:options, "option #{index + 1} title too long (maximum 50 characters)")
      end
    end
  end

  def validate_expiry_time
    return unless expires_at

    min_expiry = 5.minutes.from_now
    max_expiry = 1.month.from_now

    if expires_at < min_expiry
      errors.add(:expires_at, 'must be at least 5 minutes from now')
    elsif expires_at > max_expiry
      errors.add(:expires_at, 'cannot be more than 1 month from now')
    end
  end

  def validate_not_expired_on_create
    return unless expires_at && new_record?

    if expires_at <= Time.current
      errors.add(:expires_at, 'cannot be in the past')
    end
  end

  def calculate_vote_counts
    self.votes_count = poll_votes.count
    self.voters_count = poll_votes.distinct.count(:actor_id)
  end

  def serialize_options
    return [] unless options.is_a?(Array)

    options.each_with_index.map do |option, index|
      {
        title: option['title'] || option[:title],
        votes_count: option_votes_count(index)
      }
    end
  end
end