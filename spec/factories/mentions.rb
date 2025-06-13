# frozen_string_literal: true

FactoryBot.define do
  factory :mention do
    association :actor, :local
    association :object, factory: :activity_pub_object
    sequence(:acct) { |n| "user#{n}@example.com" }

    trait :local_mention do
      acct { actor.username }
    end

    trait :remote_mention do
      association :actor, :remote
      acct { "#{actor.username}@#{actor.domain}" }
    end
  end
end
