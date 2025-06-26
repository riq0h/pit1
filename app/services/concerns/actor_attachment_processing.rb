# frozen_string_literal: true

module ActorAttachmentProcessing
  extend ActiveSupport::Concern

  private

  def extract_fields_from_attachments(actor_data)
    attachments = actor_data['attachment'] || []
    return [] unless attachments.is_a?(Array)

    attachments.filter_map do |attachment|
      next unless attachment.is_a?(Hash) && attachment['type'] == 'PropertyValue'

      {
        name: attachment['name'],
        value: attachment['value']
      }
    end
  end
end
