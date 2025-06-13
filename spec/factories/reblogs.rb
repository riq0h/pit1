# frozen_string_literal: true

FactoryBot.define do
  factory :reblog do
    association :actor, :local
    association :object, factory: :activity_pub_object

    trait :with_remote_actor do
      association :actor, :remote
    end

    trait :with_activity do
      after(:create) do |reblog|
        create(:activity,
               actor: reblog.actor,
               activity_type: 'Announce',
               object: reblog.object,
               local: reblog.actor.local?)
      end
    end
  end
end
