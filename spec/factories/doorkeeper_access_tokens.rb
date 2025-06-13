# frozen_string_literal: true

FactoryBot.define do
  factory :doorkeeper_access_token, class: 'Doorkeeper::AccessToken' do
    association :application, factory: :doorkeeper_application
    resource_owner_id { create(:actor, :local).id }
    token { SecureRandom.hex(32) }
    expires_in { 7200 }
    scopes { 'read write follow push' }

    trait :read_only do
      scopes { 'read' }
    end

    trait :write_only do
      scopes { 'write' }
    end

    trait :expired do
      created_at { 3.hours.ago }
      expires_in { 7200 }
    end
  end

  factory :doorkeeper_application, class: 'Doorkeeper::Application' do
    sequence(:name) { |n| "Test App #{n}" }
    uid { SecureRandom.hex(20) }
    secret { SecureRandom.hex(40) }
    redirect_uri { 'urn:ietf:wg:oauth:2.0:oob' }
    scopes { 'read write follow push' }
  end
end
