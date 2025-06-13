# frozen_string_literal: true

FactoryBot.define do
  factory :favourite do
    association :actor, :local
    association :object, factory: :activity_pub_object

    trait :with_remote_actor do
      association :actor, :remote
    end

    trait :with_activity do
      after(:create) do |favourite|
        create(:activity,
               actor: favourite.actor,
               activity_type: 'Like',
               object: favourite.object,
               local: favourite.actor.local?)
      end
    end
  end
end
