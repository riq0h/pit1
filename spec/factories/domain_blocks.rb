# frozen_string_literal: true

FactoryBot.define do
  factory :domain_block do
    association :actor, :local
    sequence(:domain) { |n| "blocked#{n}.example.com" }

    trait :popular_domain do
      domain { 'mastodon.social' }
    end

    trait :malicious_domain do
      domain { 'malicious.example' }
    end
  end
end
