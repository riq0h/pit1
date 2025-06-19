# frozen_string_literal: true

module NotificationSerializer
  extend ActiveSupport::Concern
  
  included do
    include StatusSerializationHelper
    include MediaSerializer
  end

  def serialized_notification(notification)
    {
      id: notification.id.to_s,
      type: notification.notification_type,
      created_at: notification.created_at.iso8601,
      account: serialized_account(notification.from_actor),
      status: notification.target_object ? serialized_status(notification.target_object) : nil
    }
  end
end