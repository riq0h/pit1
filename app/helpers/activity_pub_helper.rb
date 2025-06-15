# frozen_string_literal: true

module ActivityPubHelper
  def fetch_activitypub_object(uri)
    response = HTTParty.get(uri, {
                              headers: {
                                'Accept' => 'application/activity+json, application/ld+json; profile="https://www.w3.org/ns/activitystreams"',
                                'User-Agent' => 'Letter/1.0 (ActivityPub Bot)'
                              },
                              timeout: 10
                            })

    return nil unless response.success?

    JSON.parse(response.body)
  rescue StandardError => e
    Rails.logger.error "ActivityPub object fetch failed for #{uri}: #{e.message}"
    nil
  end
end
