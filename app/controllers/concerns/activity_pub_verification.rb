# frozen_string_literal: true

require_relative '../../lib/exceptions'

module ActivityPubVerification
  extend ActiveSupport::Concern

  private

  # Content-Type検証
  def verify_content_type
    content_type = request.content_type

    return if valid_content_type?(content_type)

    Rails.logger.warn "❌ Invalid Content-Type: #{content_type}"
    head :unsupported_media_type
    false
  end

  def valid_content_type?(content_type)
    return false unless content_type

    content_type.include?('application/json') ||
      content_type.include?('application/activity+json') ||
      content_type.include?('application/ld+json')
  end

  # 宛先アクター検索
  def find_target_actor
    username = params[:username]
    @target_actor = Actor.find_by(username: username, local: true)

    return if @target_actor

    Rails.logger.warn "❌ Target actor not found: #{username}"
    head :not_found
    false
  end

  # Activity JSON解析
  def parse_activity_json
    @activity = JSON.parse(request.body.read)

    validate_activity_structure
    check_json_ld_context
  rescue JSON::ParserError => e
    raise ActivityPub::ValidationError, "Invalid JSON: #{e.message}"
  end

  def validate_activity_structure
    return if @activity.is_a?(Hash) && @activity['type'] && @activity['actor']

    raise ActivityPub::ValidationError, 'Invalid activity structure'
  end

  def check_json_ld_context
    context = @activity['@context']
    return if context&.include?('https://www.w3.org/ns/activitystreams')

    Rails.logger.warn '⚠️ Missing or invalid @context'
  end

  # HTTP Signature検証
  def verify_http_signature
    signature_header = request.headers['Signature']

    raise ActivityPub::SignatureError, 'Missing Signature header' unless signature_header

    verify_signature
  end

  def verify_signature
    verifier = create_signature_verifier
    return if verifier.verify!(@activity['actor'])

    raise ::ActivityPub::SignatureError, 'Signature verification failed'
  end

  def create_signature_verifier
    HttpSignatureVerifier.new(
      method: request.method,
      path: request.fullpath,
      headers: request.headers,
      body: @activity.to_json
    )
  end

  # 送信者アクター取得・作成
  def find_or_create_sender
    actor_uri = @activity['actor']
    @sender = Actor.find_by(ap_id: actor_uri)

    return if @sender

    fetch_remote_actor(actor_uri)
  end

  def fetch_remote_actor(actor_uri)
    fetcher = ActorFetcher.new
    @sender = fetcher.fetch_and_create(actor_uri)

    raise ActivityPub::ValidationError, "Failed to fetch actor: #{actor_uri}" unless @sender

    Rails.logger.info "👤 New remote actor created: #{@sender.username}@#{@sender.domain}"
  end
end
