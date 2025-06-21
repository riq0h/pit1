# frozen_string_literal: true

class PollVote < ApplicationRecord
  belongs_to :poll
  belongs_to :actor

  validates :choice, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validate :validate_choice_within_options
  validate :validate_poll_not_expired
  validate :validate_single_choice_constraint

  private

  def validate_choice_within_options
    return unless poll && choice

    unless choice < poll.options.length
      errors.add(:choice, 'is not a valid option')
    end
  end

  def validate_poll_not_expired
    return unless poll

    if poll.expired?
      errors.add(:poll, 'has expired')
    end
  end

  def validate_single_choice_constraint
    return unless poll && actor && choice && !poll.multiple

    # 単一選択の場合、同じアクターが複数の選択肢に投票できない
    existing_votes = poll.poll_votes.where(actor: actor).where.not(id: id)
    if existing_votes.exists?
      errors.add(:actor, 'can only vote for one option in single-choice polls')
    end
  end
end