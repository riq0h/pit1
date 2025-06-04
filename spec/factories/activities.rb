# frozen_string_literal: true

FactoryBot.define do
  factory :activity do
    sequence(:ap_id) { |n| "https://example.com/activities/#{n}" }
    activity_type { 'Create' }
    association :actor
    published_at { Time.current }
    local { true }
    processed { false }

    # JSON-LD形式のraw_data
    raw_data do
      {
        '@context' => 'https://www.w3.org/ns/activitystreams',
        'id' => ap_id,
        'type' => activity_type,
        'actor' => actor.ap_id,
        'published' => published_at.iso8601
      }
    end

    trait :create do
      activity_type { 'Create' }
      association :object

      raw_data do
        {
          '@context' => 'https://www.w3.org/ns/activitystreams',
          'id' => ap_id,
          'type' => 'Create',
          'actor' => actor.ap_id,
          'object' => object.ap_id,
          'published' => published_at.iso8601
        }
      end
    end

    trait :follow do
      activity_type { 'Follow' }
      target_ap_id { 'https://remote.example/users/bob' }

      raw_data do
        {
          '@context' => 'https://www.w3.org/ns/activitystreams',
          'id' => ap_id,
          'type' => 'Follow',
          'actor' => actor.ap_id,
          'object' => target_ap_id,
          'published' => published_at.iso8601
        }
      end
    end

    trait :like do
      activity_type { 'Like' }
      target_ap_id { 'https://example.com/posts/abc123' }

      raw_data do
        {
          '@context' => 'https://www.w3.org/ns/activitystreams',
          'id' => ap_id,
          'type' => 'Like',
          'actor' => actor.ap_id,
          'object' => target_ap_id,
          'published' => published_at.iso8601
        }
      end
    end

    trait :announce do
      activity_type { 'Announce' }
      target_ap_id { 'https://example.com/posts/xyz789' }

      raw_data do
        {
          '@context' => 'https://www.w3.org/ns/activitystreams',
          'id' => ap_id,
          'type' => 'Announce',
          'actor' => actor.ap_id,
          'object' => target_ap_id,
          'published' => published_at.iso8601
        }
      end
    end

    trait :accept do
      activity_type { 'Accept' }
      target_ap_id { 'https://example.com/activities/follow-123' }

      raw_data do
        {
          '@context' => 'https://www.w3.org/ns/activitystreams',
          'id' => ap_id,
          'type' => 'Accept',
          'actor' => actor.ap_id,
          'object' => target_ap_id,
          'published' => published_at.iso8601
        }
      end
    end

    trait :remote do
      local { false }
      sequence(:ap_id) { |n| "https://remote.example/activities/#{n}" }

      raw_data do
        {
          '@context' => 'https://www.w3.org/ns/activitystreams',
          'id' => ap_id,
          'type' => activity_type,
          'actor' => "https://remote.example/users/#{actor.username}",
          'published' => published_at.iso8601
        }
      end
    end

    trait :processed do
      processed { true }
      processed_at { Time.current }
    end
  end
end
