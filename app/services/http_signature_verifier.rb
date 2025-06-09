# frozen_string_literal: true

class HttpSignatureVerifier
  attr_reader :method, :path, :headers, :body

  def initialize(method:, path:, headers:, body:)
    @method = method.upcase
    @path = path
    @headers = headers
    @body = body
  end

  def verify!(actor_uri)
    # Signature header解析
    signature_params = parse_signature_header

    # アクター公開鍵取得
    public_key = fetch_actor_public_key(actor_uri)

    # 署名文字列構築
    signing_string = build_signing_string(signature_params['headers'])

    # 署名検証
    verify_signature(
      signature: signature_params['signature'],
      signing_string: signing_string,
      public_key: public_key
    )
  rescue StandardError => e
    Rails.logger.error "🔒 Signature verification failed: #{e.message}"
    false
  end

  private

  # Signature header解析
  def parse_signature_header
    signature_header = headers['Signature']
    raise ActivityPub::SignatureError, 'Missing Signature header' unless signature_header

    params = {}

    # keyId="...",algorithm="...",headers="...",signature="..."
    signature_header.scan(/(\w+)="([^"]*)"/) do |key, value|
      params[key] = value
    end

    required_params = %w[keyId algorithm headers signature]
    missing = required_params - params.keys

    raise ActivityPub::SignatureError, "Missing signature parameters: #{missing.join(', ')}" if missing.any?

    Rails.logger.debug { "🔒 Signature params: keyId=#{params['keyId']}, algorithm=#{params['algorithm']}" }

    params
  end

  # アクター公開鍵取得
  def fetch_actor_public_key(actor_uri)
    # キャッシュ確認
    actor = Actor.find_by(ap_id: actor_uri)

    if actor&.public_key.present?
      Rails.logger.debug { "🔑 Using cached public key for #{actor_uri}" }
      return parse_public_key(actor.public_key)
    end

    # リモートから取得
    Rails.logger.debug { "🌐 Fetching actor from #{actor_uri}" }

    response = fetch_actor_data(actor_uri)
    public_key_data = response.dig('publicKey', 'publicKeyPem')

    raise ActivityPub::SignatureError, 'No public key found in actor data' unless public_key_data

    # アクター情報更新/作成
    if actor
      actor.update!(public_key: public_key_data)
    else
      create_remote_actor(actor_uri, response, public_key_data)
    end

    parse_public_key(public_key_data)
  end

  # アクターデータ取得
  def fetch_actor_data(actor_uri)
    uri = URI(actor_uri)
    http = configure_http_client(uri)
    request = build_actor_request(uri)
    response = http.request(request)

    validate_response(response)
    JSON.parse(response.body)
  rescue JSON::ParserError => e
    raise ActivityPub::SignatureError, "Invalid JSON in actor response: #{e.message}"
  rescue StandardError => e
    raise ActivityPub::SignatureError, "Network error fetching actor: #{e.message}"
  end

  # リモートアクター作成
  def create_remote_actor(actor_uri, actor_data, public_key_data)
    uri = URI(actor_uri)
    username = actor_data['preferredUsername'] || File.basename(uri.path)
    domain = uri.host

    Actor.create!(
      ap_id: actor_uri,
      username: username,
      domain: domain,
      display_name: actor_data['name'],
      summary: actor_data['summary'],
      inbox_url: actor_data['inbox'],
      outbox_url: actor_data['outbox'],
      followers_url: actor_data['followers'],
      following_url: actor_data['following'],
      public_key: public_key_data,
      icon_url: actor_data.dig('icon', 'url'),
      header_url: actor_data.dig('image', 'url'),
      raw_data: actor_data,
      local: false
    )

    Rails.logger.info "👤 Remote actor created: #{username}@#{domain}"
  end

  # 公開鍵解析
  def parse_public_key(public_key_pem)
    OpenSSL::PKey::RSA.new(public_key_pem)
  rescue StandardError => e
    raise ActivityPub::SignatureError, "Invalid public key format: #{e.message}"
  end

  # 署名文字列構築
  def build_signing_string(headers_list)
    header_names = headers_list.split
    signature_parts = build_signature_parts(header_names)
    signing_string = signature_parts.join("\n")

    Rails.logger.debug { "🔒 Signing string:\n#{signing_string}" }
    signing_string
  end

  def configure_http_client(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    http.read_timeout = 10
    http.open_timeout = 5
    http
  end

  def build_actor_request(uri)
    request = Net::HTTP::Get.new(uri.path)
    request['Accept'] = 'application/activity+json, application/ld+json; profile="https://www.w3.org/ns/activitystreams"'
    request['User-Agent'] = 'pit1/0.1 (ActivityPub)'
    request
  end

  def validate_response(response)
    raise ActivityPub::SignatureError, "Failed to fetch actor: HTTP #{response.code}" unless response.code == '200'
  end

  def build_signature_parts(header_names)
    header_names.map do |header_name|
      build_signature_part(header_name)
    end
  end

  def build_signature_part(header_name)
    normalized_name = header_name.downcase
    if normalized_name == '(request-target)'
      build_request_target_header
    elsif standard_headers.key?(normalized_name)
      build_standard_header(normalized_name)
    else
      build_custom_header(header_name)
    end
  end

  def standard_headers
    {
      'host' => headers['Host'],
      'date' => headers['Date'],
      'digest' => headers['Digest'],
      'content-type' => headers['Content-Type'],
      'content-length' => headers['Content-Length']
    }
  end

  def build_request_target_header
    "(request-target): #{method.downcase} #{path}"
  end

  def build_standard_header(header_name)
    "#{header_name}: #{standard_headers[header_name]}"
  end

  def build_custom_header(header_name)
    value = headers[header_name] || headers[header_name.titleize]
    "#{header_name.downcase}: #{value}"
  end

  # 署名検証
  def verify_signature(signature:, signing_string:, public_key:)
    decoded_signature = Base64.decode64(signature)

    verified = public_key.verify(
      OpenSSL::Digest.new('SHA256'),
      decoded_signature,
      signing_string
    )

    if verified
      Rails.logger.debug '✅ Signature verification successful'
      true
    else
      Rails.logger.warn '❌ Signature verification failed'
      false
    end
  rescue StandardError => e
    Rails.logger.error "❌ Signature verification error: #{e.message}"
    false
  end
end
