# frozen_string_literal: true

class SendActivityJob < ApplicationJob
  queue_as :default

  # Activity配信ジョブ
  # @param activity_id [String] 送信するActivityのID
  # @param target_inboxes [Array<String>] 配信先Inbox URLの配列
  def perform(activity_id, target_inboxes)
    @activity = Activity.find(activity_id)

    Rails.logger.info "📤 Sending #{@activity.activity_type} activity #{@activity.id} to #{target_inboxes.count} inboxes"

    target_inboxes.each do |inbox_url|
      send_to_inbox(inbox_url)
    end

    @activity.update!(
      delivered: true,
      delivered_at: Time.current,
      delivery_attempts: @activity.delivery_attempts + 1
    )
  rescue ActiveRecord::RecordNotFound
    Rails.logger.error "❌ Activity #{activity_id} not found"
  rescue StandardError => e
    handle_job_error(e, activity_id)
  end

  private

  def send_to_inbox(inbox_url)
    activity_data = build_activity_data(@activity)
    sender = ActivitySender.new

    success = sender.send_activity(
      activity: activity_data,
      target_inbox: inbox_url,
      signing_actor: @activity.actor
    )

    log_delivery_result(success, inbox_url)
    success
  rescue StandardError => e
    Rails.logger.error "💥 Failed to send to #{inbox_url}: #{e.message}"
    false
  end

  def build_activity_data(activity)
    case activity.activity_type
    when 'Create'
      ActivityBuilders::CreateActivityBuilder.new(activity).build
    when 'Announce'
      ActivityBuilders::AnnounceActivityBuilder.new(activity).build
    when 'Update'
      build_update_activity_data(activity)
    else
      ActivityBuilders::SimpleActivityBuilder.new(activity).build
    end
  end

  def build_update_activity_data(activity)
    Rails.logger.info "🔄 Building Update activity data for #{activity.id}"

    unless activity.object
      Rails.logger.warn "⚠️ Update activity #{activity.id} has no object"
      return ActivityBuilders::SimpleActivityBuilder.new(activity).build
    end

    {
      '@context' => 'https://www.w3.org/ns/activitystreams',
      'id' => activity.ap_id,
      'type' => 'Update',
      'actor' => activity.actor.ap_id,
      'published' => activity.published_at.iso8601,
      'object' => build_updated_object_data(activity.object),
      'to' => build_activity_audience(activity.object, :to),
      'cc' => build_activity_audience(activity.object, :cc)
    }
  end

  def build_updated_object_data(object)
    updated_data = {
      '@context' => 'https://www.w3.org/ns/activitystreams',
      'id' => object.ap_id,
      'type' => object.object_type,
      'attributedTo' => object.actor.ap_id,
      'content' => object.content,
      'published' => object.published_at.iso8601,
      'url' => object.public_url,
      'to' => build_activity_audience(object, :to),
      'cc' => build_activity_audience(object, :cc),
      'sensitive' => object.sensitive?,
      'summary' => object.summary,
      'inReplyTo' => object.in_reply_to_ap_id,
      'attachment' => build_object_attachments(object),
      'tag' => build_object_tags(object)
    }

    updated_data['updated'] = object.edited_at.iso8601 if object.edited?
    updated_data.compact
  end

  def build_object_attachments(object)
    ActivityBuilders::AttachmentBuilder.new(object).build
  end

  def build_object_tags(object)
    ActivityBuilders::TagBuilder.new(object).build
  end

  def build_activity_audience(object, type)
    ActivityBuilders::AudienceBuilder.new(object).build(type)
  end

  def log_delivery_result(success, inbox_url)
    if success
      Rails.logger.info "✅ Successfully sent to #{inbox_url}"
    else
      Rails.logger.warn "❌ Failed to send to #{inbox_url}"
    end
  end

  def handle_job_error(error, activity_id)
    log_error_details(error, activity_id)
    update_activity_error_info(error)
    handle_retry_logic(activity_id)
  end

  def log_error_details(error, activity_id)
    Rails.logger.error "💥 SendActivityJob error for activity #{activity_id}: #{error.message}"
    Rails.logger.error error.backtrace.first(5).join("\n")
  end

  def update_activity_error_info(error)
    @activity&.update!(
      delivery_attempts: @activity.delivery_attempts + 1,
      last_delivery_error: "#{error.class}: #{error.message}"
    )
  end

  def handle_retry_logic(activity_id)
    if executions < 3
      retry_job(wait: exponential_backoff)
    else
      handle_permanent_failure(activity_id)
    end
  end

  def handle_permanent_failure(activity_id)
    Rails.logger.error "💥 SendActivityJob failed permanently for activity #{activity_id}"
    @activity&.update!(last_delivery_error: "Permanent failure after #{executions} attempts")
  end

  def exponential_backoff
    (executions**2).minutes
  end
end
