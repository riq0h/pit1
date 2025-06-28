# frozen_string_literal: true

class ActorKeyManager
  def initialize(actor)
    @actor = actor
  end

  def public_key_object
    return nil if actor.public_key.blank?

    OpenSSL::PKey::RSA.new(actor.public_key)
  rescue OpenSSL::PKey::RSAError => e
    Rails.logger.error "Failed to parse public key for actor #{actor.id}: #{e.message}"
    nil
  end

  def private_key_object
    return nil if actor.private_key.blank?

    OpenSSL::PKey::RSA.new(actor.private_key)
  rescue OpenSSL::PKey::RSAError => e
    Rails.logger.error "Failed to parse private key for actor #{actor.id}: #{e.message}"
    nil
  end

  def public_key_id
    "#{actor.ap_id}#main-key"
  end

  def generate_key_pair
    return unless actor.local?

    rsa_key = OpenSSL::PKey::RSA.new(2048)
    actor.private_key = rsa_key.to_pem
    actor.public_key = rsa_key.public_key.to_pem
  rescue OpenSSL::PKey::RSAError => e
    Rails.logger.error "Failed to generate key pair for actor #{actor.id}: #{e.message}"
    raise
  end

  private

  attr_reader :actor
end
