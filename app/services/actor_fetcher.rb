# frozen_string_literal: true

class ActorFetcher
  include HTTParty

  def initialize
    @timeout = 15
  end

  def fetch_and_create(actor_uri)
    Rails.logger.info "🌐 Fetching actor: #{actor_uri}"

    # 重複チェック
    existing_actor = Actor.find_by(ap_id: actor_uri)
    return existing_actor if existing_actor

    # アクターデータ取得
    actor_data = fetch_actor_data(actor_uri)

    # アクター作成
    create_actor_from_data(actor_uri, actor_data)
  rescue StandardError => e
    Rails.logger.error "❌ Actor fetch failed: #{e.message}"
    nil
  end

  def fetch_actor_data(actor_uri)
    response = perform_actor_request(actor_uri)
    actor_data = parse_actor_response(response)
    validate_actor_data(actor_data)

    actor_data
  rescue JSON::ParserError => e
    raise ActivityPub::ActorFetchError, "Invalid JSON response: #{e.message}"
  rescue Net::TimeoutError => e
    raise ActivityPub::ActorFetchError, "Request timeout: #{e.message}"
  end

  def create_actor_from_data(actor_uri, actor_data)
    uri = URI(actor_uri)
    username, domain = extract_actor_identity(actor_data, uri)
    public_key_pem = extract_public_key(actor_data)

    actor = Actor.create!(build_actor_attributes(actor_uri, actor_data, username, domain, public_key_pem))

    Rails.logger.info "👤 Remote actor created: #{username}@#{domain}"
    actor
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "💾 Actor creation failed: #{e.message}"
    raise ActivityPub::ActorFetchError, "Database error: #{e.message}"
  end

  private

  def perform_actor_request(actor_uri)
    HTTParty.get(
      actor_uri,
      headers: {
        'Accept' => 'application/activity+json, application/ld+json; profile="https://www.w3.org/ns/activitystreams"',
        'User-Agent' => 'letter/0.1 (ActivityPub)'
      },
      timeout: @timeout,
      follow_redirects: true
    )
  end

  def parse_actor_response(response)
    raise ActivityPub::ActorFetchError, "HTTP #{response.code}: #{response.message}" unless response.success?

    JSON.parse(response.body)
  end

  def validate_actor_data(actor_data)
    unless actor_data['type']&.match?(/Person|Service|Organization|Group/)
      raise ActivityPub::ActorFetchError,
            "Invalid actor type: #{actor_data['type']}"
    end

    required_fields = %w[id inbox outbox publicKey]
    missing_fields = required_fields.select { |field| actor_data[field].blank? }

    raise ActivityPub::ActorFetchError, "Missing required fields: #{missing_fields.join(', ')}" if missing_fields.any?
  end

  def extract_actor_identity(actor_data, uri)
    username = actor_data['preferredUsername'] ||
               actor_data['name']&.downcase&.gsub(/[^a-zA-Z0-9_]/, '') ||
               File.basename(uri.path)
    domain = uri.host
    [username, domain]
  end

  def extract_public_key(actor_data)
    public_key_pem = actor_data.dig('publicKey', 'publicKeyPem')
    raise ActivityPub::ActorFetchError, 'Missing public key in actor data' unless public_key_pem

    public_key_pem
  end

  def build_actor_attributes(actor_uri, actor_data, username, domain, public_key_pem)
    {
      ap_id: actor_uri,
      username: username,
      domain: domain,
      display_name: actor_data['name'],
      summary: actor_data['summary'],
      actor_type: actor_data['type'],
      inbox_url: actor_data['inbox'],
      outbox_url: actor_data['outbox'],
      followers_url: actor_data['followers'],
      following_url: actor_data['following'],
      featured_url: actor_data['featured'],
      public_key: public_key_pem,
      raw_data: actor_data,
      local: false,
      discoverable: actor_data['discoverable'] != false,
      manually_approves_followers: actor_data['manuallyApprovesFollowers'] == true
    }
  end

  # 画像URL抽出（icon/header）
  def extract_image_url(image_data)
    return nil if image_data.blank?

    case image_data
    when String
      image_data
    when Hash
      image_data['url'] || image_data['href']
    when Array
      image_data.first&.dig('url') || image_data.first&.dig('href')
    end
  end
end
