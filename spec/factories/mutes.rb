# frozen_string_literal: true

FactoryBot.define do
  factory :mute do
    actor { association :actor }
    target_actor { association :actor }
    ap_id { "https://example.com/mutes/#{SecureRandom.uuid}" }
    notifications { true }

    trait :without_notifications do
      notifications { false }
    end
  end
end
