# frozen_string_literal: true

class List < ApplicationRecord
  belongs_to :actor
  has_many :list_memberships, dependent: :destroy
  has_many :members, through: :list_memberships, source: :actor

  validates :title, presence: true, length: { maximum: 100 }
  validates :replies_policy, inclusion: { in: %w[list followed none] }
  validates :exclusive, inclusion: { in: [true, false] }

  scope :recent, -> { order(updated_at: :desc) }

  def add_member!(member_actor)
    list_memberships.find_or_create_by!(actor: member_actor)
  end

  def remove_member!(member_actor)
    list_memberships.find_by(actor: member_actor)&.destroy
  end

  def includes_member?(member_actor)
    list_memberships.exists?(actor: member_actor)
  end
end
