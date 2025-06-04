# frozen_string_literal: true

FactoryBot.define do
  factory :actor do
    sequence(:username) { |n| "user#{n}" }
    ap_id { "https://example.com/users/#{username}" }
    inbox_url { "#{ap_id}/inbox" }
    outbox_url { "#{ap_id}/outbox" }
    public_key do
      "-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA...\n-----END PUBLIC KEY-----"
    end
    local { false }

    trait :local do
      local { true }
      domain { nil }
      private_key { "-----BEGIN RSA PRIVATE KEY-----\nMIIEpAIBAAKCAQEA...\n-----END RSA PRIVATE KEY-----" }
    end

    trait :remote do
      local { false }
      domain { 'example.com' }
      private_key { nil }
    end
  end
end
