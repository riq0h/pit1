# frozen_string_literal: true

FactoryBot.define do
  factory :actor do
    sequence(:username) { |n| "user#{n}" }
    display_name { Faker::Name.name }
    note { Faker::Lorem.paragraph }
    local { true }
    domain { nil }
    discoverable { true }
    manually_approves_followers { false }

    # ローカルユーザの場合の必須フィールド
    before(:create) do |actor|
      if actor.local?
        actor.private_key = OpenSSL::PKey::RSA.new(2048).to_pem
        actor.public_key = OpenSSL::PKey::RSA.new(actor.private_key).public_key.to_pem

        base_url = Rails.application.config.activitypub.base_url
        user_base = "#{base_url}/users/#{actor.username}"

        actor.ap_id = user_base
        actor.inbox_url = "#{user_base}/inbox"
        actor.outbox_url = "#{user_base}/outbox"
        actor.followers_url = "#{user_base}/followers"
        actor.following_url = "#{user_base}/following"
        actor.featured_url = "#{user_base}/collections/featured"
      end
    end

    trait :remote do
      local { false }
      domain { 'remote.example.com' }
      sequence(:ap_id) { |n| "https://remote.example.com/users/user#{n}" }
      sequence(:inbox_url) { |n| "https://remote.example.com/users/user#{n}/inbox" }
      sequence(:outbox_url) { |n| "https://remote.example.com/users/user#{n}/outbox" }
      sequence(:followers_url) { |n| "https://remote.example.com/users/user#{n}/followers" }
      sequence(:following_url) { |n| "https://remote.example.com/users/user#{n}/following" }
      public_key { OpenSSL::PKey::RSA.new(2048).public_key.to_pem }
    end

    trait :admin do
      admin { true }
    end
  end
end
