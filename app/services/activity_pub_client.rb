# frozen_string_literal: true

class ActivityPubClient
  include HTTParty

  def self.fetch_object(uri)
    new.fetch_object(uri)
  end

  def fetch_object(uri)
    Rails.logger.debug "🌐 Fetching ActivityPub object: #{uri}"

    response = HTTParty.get(
      uri,
      headers: headers,
      timeout: 10,
      follow_redirects: true
    )

    return nil unless response.success?

    JSON.parse(response.body)
  rescue JSON::ParserError => e
    Rails.logger.error "❌ Invalid JSON in ActivityPub object #{uri}: #{e.message}"
    nil
  rescue Net::TimeoutError => e
    Rails.logger.error "❌ Timeout fetching ActivityPub object #{uri}: #{e.message}"
    nil
  rescue StandardError => e
    Rails.logger.error "❌ Failed to fetch ActivityPub object #{uri}: #{e.message}"
    nil
  end

  private

  def headers
    {
      'Accept' => 'application/activity+json, application/ld+json; profile="https://www.w3.org/ns/activitystreams"',
      'User-Agent' => 'letter/0.1 (ActivityPub)'
    }
  end
end