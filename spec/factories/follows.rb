# frozen_string_literal: true

FactoryBot.define do
  factory :follow do
    association :actor, factory: :actor
    association :target_actor, factory: %i[actor remote]
    accepted { false }
    sequence(:ap_id) { |n| "https://test.example.com/follows/#{n}" }
    sequence(:follow_activity_ap_id) { |n| "https://test.example.com/activities/follow_#{n}" }

    trait :accepted do
      accepted { true }
    end

    trait :remote do
      association :actor, factory: :actor, local: false
      sequence(:ap_id) { |n| "https://remote.example.com/follows/#{n}" }
      sequence(:follow_activity_ap_id) { |n| "https://remote.example.com/activities/follow_#{n}" }
    end

    trait :local do
      association :actor, factory: :actor
      association :target_actor, factory: :actor
    end
  end
end
