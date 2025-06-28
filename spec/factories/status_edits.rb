# frozen_string_literal: true

FactoryBot.define do
  factory :status_edit do
    object { association :activity_pub_object }
    content { 'Original content before edit' }
    summary { nil }
    sensitive { false }
    language { 'ja' }

    trait :sensitive do
      sensitive { true }
      summary { 'Sensitive content warning' }
    end
  end
end
