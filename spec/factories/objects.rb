# frozen_string_literal: true

FactoryBot.define do
  factory :object, class: 'ActivityPubObject' do
    sequence(:ap_id) { |_n| "https://example.com/objects/#{SecureRandom.alphanumeric(21)}" }
    object_type { 'Note' }
    association :actor

    content { '<p>This is a test post for pit1 ActivityPub server! 🚀</p>' }
    content_plaintext { 'This is a test post for pit1 ActivityPub server! 🚀' }
    summary { nil }
    url { ap_id }
    language { 'ja' }

    visibility { 'public' }
    sensitive { false }
    local { true }
    published_at { Time.current }

    replies_count { 0 }
    reblogs_count { 0 }
    favourites_count { 0 }

    raw_data do
      {
        '@context' => 'https://www.w3.org/ns/activitystreams',
        'id' => ap_id,
        'type' => object_type,
        'attributedTo' => actor.ap_id,
        'content' => content,
        'published' => published_at.iso8601,
        'to' => ['https://www.w3.org/ns/activitystreams#Public'],
        'cc' => ["#{actor.ap_id}/followers"]
      }
    end

    trait :note do
      object_type { 'Note' }
    end

    trait :article do
      object_type { 'Article' }
      content { '<h1>Test Article</h1><p>This is a longer article content for testing purposes.</p>' }
      content_plaintext { 'Test Article\n\nThis is a longer article content for testing purposes.' }
    end

    trait :long_post do
      content { "<p>#{'A' * 5000}</p>" }
      content_plaintext { 'A' * 5000 }
    end

    trait :max_length do
      content { "<p>#{'X' * 9999}</p>" }
      content_plaintext { 'X' * 9999 }
    end

    trait :with_summary do
      summary { 'Content Warning: Test post' }
      sensitive { true }
    end

    trait :unlisted do
      visibility { 'unlisted' }
    end

    trait :followers_only do
      visibility { 'followers_only' }
    end

    trait :direct do
      visibility { 'direct' }
    end

    trait :with_media do
      after(:create) do |object|
        create(:media_attachment, object: object, actor: object.actor)
      end
    end

    trait :with_multiple_media do
      after(:create) do |object|
        create_list(:media_attachment, 3, object: object, actor: object.actor)
      end
    end

    trait :reply do
      in_reply_to_ap_id { 'https://example.com/objects/parent-post' }
      conversation_ap_id { 'https://example.com/objects/conversation-1' }

      content { '<p>This is a reply to another post.</p>' }
      content_plaintext { 'This is a reply to another post.' }
    end

    trait :in_conversation do
      conversation_ap_id { 'https://example.com/objects/conversation-1' }
    end

    trait :remote do
      local { false }
      sequence(:ap_id) { |n| "https://remote.example/objects/#{n}" }
      association :actor, :remote
    end

    trait :with_hashtags do
      content { '<p>Testing #ActivityPub and #Rails integration! #pit1</p>' }
      content_plaintext { 'Testing #ActivityPub and #Rails integration! #pit1' }
    end

    trait :with_mentions do
      content { '<p>Hello <a href="https://example.com/users/alice">@alice</a>!</p>' }
      content_plaintext { 'Hello @alice!' }
    end

    trait :popular do
      replies_count { 10 }
      reblogs_count { 25 }
      favourites_count { 42 }
    end
  end
end
