# frozen_string_literal: true

class PublishScheduledStatusJob < ApplicationJob
  queue_as :default

  def perform(scheduled_status_id)
    scheduled_status = ScheduledStatus.find_by(id: scheduled_status_id)
    return unless scheduled_status

    scheduled_status.publish!
  rescue StandardError => e
    Rails.logger.error "予約投稿実行エラー (ID: #{scheduled_status_id}): #{e.message}"
  end
end
