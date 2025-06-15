# frozen_string_literal: true

class WebFingerService
  include HTTParty

  def fetch_actor_data(acct_uri)
    # Extract username and domain from acct: URI
    username, domain = parse_acct_uri(acct_uri)
    return nil unless username && domain

    # Fetch WebFinger data
    webfinger_data = fetch_webfinger(username, domain)
    return nil unless webfinger_data

    # Extract ActivityPub actor URI
    actor_uri = extract_actor_uri(webfinger_data)
    return nil unless actor_uri

    # Fetch ActivityPub actor data
    fetch_activitypub_object(actor_uri)
  end

  private

  def parse_acct_uri(acct_uri)
    # Handle formats: acct:username@domain, @username@domain, username@domain
    clean_uri = acct_uri.gsub(/^(acct:|@)/, '')
    parts = clean_uri.split('@')

    return nil unless parts.length == 2

    [parts[0], parts[1]]
  end

  def fetch_webfinger(username, domain)
    webfinger_url = "https://#{domain}/.well-known/webfinger"
    resource = "acct:#{username}@#{domain}"

    response = HTTParty.get(webfinger_url, {
                              query: { resource: resource },
                              headers: { 'Accept' => 'application/jrd+json' },
                              timeout: 10
                            })

    return nil unless response.success?

    JSON.parse(response.body)
  rescue StandardError => e
    Rails.logger.error "WebFinger fetch failed for #{username}@#{domain}: #{e.message}"
    nil
  end

  def extract_actor_uri(webfinger_data)
    links = webfinger_data['links'] || []
    actor_link = links.find do |link|
      link['rel'] == 'self' &&
        link['type'] == 'application/activity+json'
    end

    actor_link&.dig('href')
  end

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
