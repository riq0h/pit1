# frozen_string_literal: true

class Reblog < ApplicationRecord
  belongs_to :actor, class_name: 'Actor'
  belongs_to :object, class_name: 'ActivityPubObject'

  validates :actor_id, uniqueness: { scope: :object_id }

  before_validation :set_ap_id, on: :create
  after_create :increment_reblogs_count
  after_create :send_push_notification
  after_destroy :decrement_reblogs_count

  private

  def set_ap_id
    return if ap_id.present?

    snowflake_id = Letter::Snowflake.generate
    self.ap_id = "#{Rails.application.config.activitypub.base_url}/#{snowflake_id}"
  end

  def increment_reblogs_count
    object.increment!(:reblogs_count)
  end

  def decrement_reblogs_count
    object.decrement!(:reblogs_count)
  end

  def send_push_notification
    WebPushNotificationService.notification_for_reblog(self)
  end
end
