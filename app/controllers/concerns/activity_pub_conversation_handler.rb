# frozen_string_literal: true

module ActivityPubConversationHandler
  extend ActiveSupport::Concern

  private

  def handle_direct_message_conversation(object, object_data)
    Rails.logger.info "💬 Processing DM conversation for #{object.id}"

    to_addresses = object_data['to'] || []
    local_recipients = find_local_recipients_from_addresses(to_addresses)

    if local_recipients.empty?
      Rails.logger.warn '⚠️ No local recipients found for DM'
      return
    end

    create_conversation_for_dm(object, local_recipients)
  end

  def find_local_recipients_from_addresses(to_addresses)
    local_actors = []

    to_addresses.each do |address|
      next unless local_address?(address)

      actor = Actor.find_by(ap_id: address, local: true)
      local_actors << actor if actor
    end

    local_actors
  end

  def local_address?(address)
    address.start_with?(Rails.application.config.activitypub.base_url)
  end

  def create_conversation_for_dm(object, local_recipients)
    participants = [object.actor] + local_recipients
    conversation = Conversation.find_or_create_for_actors(participants)

    object.update!(conversation: conversation)
    conversation.update_last_status!(object)

    Rails.logger.info "💬 DM conversation updated: #{conversation.id}"
  end
end
