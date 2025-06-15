# frozen_string_literal: true

FactoryBot.define do
  factory :conversation do
    last_status_id { 1 }
    unread { false }
  end
end
