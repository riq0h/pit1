# frozen_string_literal: true

FactoryBot.define do
  factory :conversation_participant do
    conversation { nil }
    actor { nil }
  end
end
