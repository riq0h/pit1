# frozen_string_literal: true

class ListMembership < ApplicationRecord
  belongs_to :list
  belongs_to :actor

  validates :list_id, uniqueness: { scope: :actor_id }
end