# frozen_string_literal: true

FactoryBot.define do
  factory :block do
    actor { association :actor }
    target_actor { association :actor }
    ap_id { "https://example.com/blocks/#{SecureRandom.hex(8)}" }
  end
end
