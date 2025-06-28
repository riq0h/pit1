# frozen_string_literal: true

FactoryBot.define do
  factory :quote_post do
    object { association :activity_pub_object }
    quoted_object { association :activity_pub_object }
    actor { association :actor }
    shallow_quote { false }
    quote_text { 'This is a quote with additional text' }
    ap_id { "https://example.com/quotes/#{SecureRandom.uuid}" }
    visibility { 'public' }

    trait :shallow do
      shallow_quote { true }
      quote_text { nil }
    end

    trait :deep do
      shallow_quote { false }
      quote_text { 'This is a deep quote with commentary' }
    end

    trait :private_quote do
      visibility { 'private' }
    end
  end
end
