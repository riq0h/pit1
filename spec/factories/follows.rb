# frozen_string_literal: true

FactoryBot.define do
  factory :follow do
    association :actor
    association :target_actor, factory: :actor
    sequence(:ap_id) { |n| "https://example.com/activities/follow-#{n}" }
    sequence(:follow_activity_ap_id) { |n| "https://example.com/activities/follow-#{n}" }
    accepted { false }
    blocked { false }

    trait :accepted do
      accepted { true }
      accepted_at { Time.current }
      sequence(:accept_activity_ap_id) { |n| "https://example.com/activities/accept-#{n}" }
    end

    trait :pending do
      accepted { false }
      accepted_at { nil }
      accept_activity_ap_id { nil }
    end

    trait :blocked do
      blocked { true }
    end

    trait :local do
      association :actor, :local
      association :target_actor, :local
    end

    trait :remote do
      association :actor, :remote
      association :target_actor, :remote
    end

    trait :cross_server do
      association :actor, :local
      association :target_actor, :remote
    end
  end
end
