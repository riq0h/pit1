# frozen_string_literal: true

FactoryBot.define do
  factory :user_limit do
    association :actor
    limit_type { 'daily_posts' }
    limit_value { 100 }
    current_usage { 0 }
    enabled { true }
    last_reset_at { Time.current }
    last_notified_at { nil }

    trait :daily_posts do
      limit_type { 'daily_posts' }
      limit_value { 100 }
    end

    trait :weekly_posts do
      limit_type { 'weekly_posts' }
      limit_value { 500 }
    end

    trait :monthly_posts do
      limit_type { 'monthly_posts' }
      limit_value { 2000 }
    end

    trait :storage_quota do
      limit_type { 'storage_quota' }
      limit_value { 1.gigabyte }
    end

    trait :bandwidth_quota do
      limit_type { 'bandwidth_quota' }
      limit_value { 10.gigabytes }
    end

    trait :follows_per_day do
      limit_type { 'follows_per_day' }
      limit_value { 50 }
    end

    trait :following_limit do
      limit_type { 'following_limit' }
      limit_value { 2000 }
    end

    trait :followers_limit do
      limit_type { 'followers_limit' }
      limit_value { 10_000 }
    end

    trait :media_uploads_per_day do
      limit_type { 'media_uploads_per_day' }
      limit_value { 20 }
    end

    trait :near_limit do
      current_usage { (limit_value * 0.85).to_i }
    end

    trait :exceeded do
      current_usage { limit_value + 10 }
    end

    trait :disabled do
      enabled { false }
    end

    trait :needs_reset do
      last_reset_at { 2.days.ago }
    end

    trait :recently_notified do
      last_notified_at { 30.minutes.ago }
    end

    # システム全体の制限用Factory
    factory :system_user_limit, class: 'UserLimit' do
      actor { nil }
      limit_type { 'max_users' }
      limit_value { 2 } # letterの2ユーザ制限
      current_usage { 0 }
    end
  end
end
