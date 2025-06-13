# frozen_string_literal: true

FactoryBot.define do
  factory :tag do
    sequence(:name) { |n| "tag#{n}" }
    usage_count { 0 }

    trait :popular do
      usage_count { 100 }
    end

    trait :japanese do
      name { '日本語タグ' }
    end
  end
end
