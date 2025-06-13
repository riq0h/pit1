# frozen_string_literal: true

FactoryBot.define do
  factory :mute do
    association :actor, :local
    association :target_actor, :remote
    notifications { true }

    trait :without_notifications do
      notifications { false }
    end

    trait :local_to_local do
      association :target_actor, :local
    end
  end
end
