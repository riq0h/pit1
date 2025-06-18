# frozen_string_literal: true

module ActivityPubBlockerControl
  extend ActiveSupport::Concern

  private

  def check_if_blocked_by_target
    return if request.headers['Signature'].blank?
    return unless @actor&.local?

    begin
      sender_actor = extract_sender_from_signature
      return unless sender_actor

      Rails.logger.info "🚫 Blocked actor #{sender_actor.ap_id} accessed #{@actor.ap_id}" if @actor.blocking?(sender_actor)
    rescue StandardError => e
      Rails.logger.warn "Failed to check block status: #{e.message}"
    end
  end

  def extract_sender_from_signature
    signature_header = parse_signature_header(request.headers['Signature'])
    key_id = signature_header['keyId']
    return unless key_id

    # key_idからactor URIを抽出
    actor_uri = extract_actor_uri_from_key_id(key_id)
    return unless actor_uri

    # 送信者アクターを取得
    Actor.find_by(ap_id: actor_uri)
  end

  def parse_signature_header(signature_header)
    # Signature: keyId="...",algorithm="...",headers="...",signature="..."
    signature_header.split(',').to_h do |part|
      key, value = part.strip.split('=', 2)
      [key, value.gsub(/^"|"$/, '')]
    end
  end

  def extract_actor_uri_from_key_id(key_id)
    # keyIdは通常 "https://example.com/users/username#main-key" の形式
    # "#" より前の部分がactor URI
    key_id.split('#').first
  end
end
