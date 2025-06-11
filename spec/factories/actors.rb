# frozen_string_literal: true

FactoryBot.define do
  factory :actor do
    sequence(:username) { |n| "user#{n}" }
    sequence(:ap_id) { |n| "https://example.com/users/user#{n}" }
    display_name { "Test User #{username.capitalize}" }
    summary { "I'm a test user for letter ActivityPub server!" }

    inbox_url { "#{ap_id}/inbox" }
    outbox_url { "#{ap_id}/outbox" }
    followers_url { "#{ap_id}/followers" }
    following_url { "#{ap_id}/following" }

    public_key do
      "-----BEGIN PUBLIC KEY-----\n" \
        "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA...\n" \
        '-----END PUBLIC KEY-----'
    end

    local { false }
    suspended { false }
    locked { false }

    followers_count { 0 }
    following_count { 0 }
    posts_count { 0 }

    trait :local do
      local { true }
      domain { nil }
      sequence(:ap_id) { |n| "https://localhost:3000/users/user#{n}" }

      private_key do
        "-----BEGIN RSA PRIVATE KEY-----\n" \
          "MIIEpAIBAAKCAQEA...\n" \
          '-----END RSA PRIVATE KEY-----'
      end

      inbox_url { "https://localhost:3000/users/#{username}/inbox" }
      outbox_url { "https://localhost:3000/users/#{username}/outbox" }
      followers_url { "https://localhost:3000/users/#{username}/followers" }
      following_url { "https://localhost:3000/users/#{username}/following" }
    end

    trait :remote do
      local { false }
      domain { 'remote.example' }
      private_key { nil }
      sequence(:ap_id) { |n| "https://remote.example/users/user#{n}" }
    end

    trait :suspended do
      suspended { true }
    end

    trait :locked do
      locked { true }
    end

    trait :with_followers do
      transient do
        followers_count_override { 5 }
      end

      followers_count { followers_count_override }
    end

    trait :with_posts do
      transient do
        posts_count_override { 3 }
      end

      posts_count { posts_count_override }

      after(:create) do |actor, evaluator|
        create_list(:object, evaluator.posts_count_override, actor: actor)
      end
    end
  end
end
