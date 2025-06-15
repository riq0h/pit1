# frozen_string_literal: true

class ConversationParticipant < ApplicationRecord
  # === アソシエーション ===
  belongs_to :conversation
  belongs_to :actor

  # === バリデーション ===
  validates :conversation_id, uniqueness: { scope: :actor_id }
end
