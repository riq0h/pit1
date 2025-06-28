# frozen_string_literal: true

FactoryBot.define do
  factory :activity do
    actor
    activity_type { 'Create' }
    sequence(:ap_id) { |n| "https://example.com/activities/#{n}" }
    published_at { Time.current }
    local { true }

    before(:create) do |activity|
      if activity.activity_type == 'Create' && activity.object_ap_id.blank?
        object = create(:activity_pub_object, actor: activity.actor)
        activity.object_ap_id = object.ap_id
      end
    end

    trait :follow do
      activity_type { 'Follow' }
      target_ap_id { 'https://example.com/users/target' }
    end

    trait :like do
      activity_type { 'Like' }
      target_ap_id { 'https://example.com/posts/123' }
    end

    trait :announce do
      activity_type { 'Announce' }
      target_ap_id { 'https://example.com/posts/123' }
    end

    trait :remote do
      local { false }
      sequence(:ap_id) { |n| "https://remote.example.com/activities/#{n}" }
    end
  end
end
