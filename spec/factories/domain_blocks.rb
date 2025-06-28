# frozen_string_literal: true

FactoryBot.define do
  factory :domain_block do
    actor { association :actor }
    domain { 'blocked-domain.com' }
    reason { 'Spam or malicious content' }
    reject_media { false }
    reject_reports { false }
    private_comment { false }
    public_comment { nil }

    trait :reject_media do
      reject_media { true }
    end

    trait :reject_reports do
      reject_reports { true }
    end

    trait :with_public_comment do
      public_comment { 'This domain has been blocked due to policy violations.' }
    end
  end
end
