# frozen_string_literal: true

FactoryBot.define do
  factory :block do
    association :actor, :local
    association :target_actor, :remote

    trait :local_to_local do
      association :target_actor, :local
    end

    trait :remote_to_local do
      association :actor, :remote
      association :target_actor, :local
    end
  end
end
