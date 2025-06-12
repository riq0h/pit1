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
      build_create_activity_data(activity)
    when 'Follow'
      build_follow_activity_data(activity)
    when 'Accept'
      build_accept_activity_data(activity)
    when 'Reject'
      build_reject_activity_data(activity)
    when 'Undo'
      build_undo_activity_data(activity)
    when 'Announce'
      build_announce_activity_data(activity)
    when 'Like'
      build_like_activity_data(activity)
    when 'Delete'
      build_delete_activity_data(activity)
    else
      build_generic_activity_data(activity)
    end
  end

  def build_create_activity_data(activity)
    return build_generic_activity_data(activity) unless activity.object

    base_data = build_create_base_data(activity)
    base_data.merge('object' => build_create_object_data(activity.object))
  end

  def build_create_base_data(activity)
    {
      '@context' => 'https://www.w3.org/ns/activitystreams',
      'id' => activity.ap_id,
      'type' => 'Create',
      'actor' => activity.actor.ap_id,
      'published' => activity.published_at.iso8601,
      'to' => build_audience(activity.object, :to),
      'cc' => build_audience(activity.object, :cc)
    }
  end

  def build_create_object_data(object)
    {
      'id' => object.ap_id,
      'type' => object.object_type,
      'attributedTo' => object.actor.ap_id,
      'content' => object.content,
      'published' => object.published_at.iso8601,
      'url' => object.public_url,
      'to' => build_audience(object, :to),
      'cc' => build_audience(object, :cc),
      'sensitive' => object.sensitive?,
      'summary' => object.summary,
      'inReplyTo' => object.in_reply_to_ap_id,
      'attachment' => build_attachments(object),
      'tag' => build_tags(object)
    }.compact
  end

  def build_follow_activity_data(activity)
    {
      '@context' => 'https://www.w3.org/ns/activitystreams',
      'id' => activity.ap_id,
      'type' => 'Follow',
      'actor' => activity.actor.ap_id,
      'object' => activity.target_ap_id,
      'published' => activity.published_at.iso8601
    }
  end

  def build_accept_activity_data(activity)
    {
      '@context' => 'https://www.w3.org/ns/activitystreams',
      'id' => activity.ap_id,
      'type' => 'Accept',
      'actor' => activity.actor.ap_id,
      'object' => activity.target_ap_id,
      'published' => activity.published_at.iso8601
    }
  end

  def build_reject_activity_data(activity)
    {
      '@context' => 'https://www.w3.org/ns/activitystreams',
      'id' => activity.ap_id,
      'type' => 'Reject',
      'actor' => activity.actor.ap_id,
      'object' => activity.target_ap_id,
      'published' => activity.published_at.iso8601
    }
  end

  def build_undo_activity_data(activity)
    {
      '@context' => 'https://www.w3.org/ns/activitystreams',
      'id' => activity.ap_id,
      'type' => 'Undo',
      'actor' => activity.actor.ap_id,
      'object' => activity.target_ap_id,
      'published' => activity.published_at.iso8601
    }
  end

  def build_announce_activity_data(activity)
    {
      '@context' => 'https://www.w3.org/ns/activitystreams',
      'id' => activity.ap_id,
      'type' => 'Announce',
      'actor' => activity.actor.ap_id,
      'object' => activity.target_ap_id,
      'published' => activity.published_at.iso8601,
      'to' => ['https://www.w3.org/ns/activitystreams#Public'],
      'cc' => [activity.actor.followers_url]
    }
  end

  def build_like_activity_data(activity)
    {
      '@context' => 'https://www.w3.org/ns/activitystreams',
      'id' => activity.ap_id,
      'type' => 'Like',
      'actor' => activity.actor.ap_id,
      'object' => activity.target_ap_id,
      'published' => activity.published_at.iso8601
    }
  end

  def build_delete_activity_data(activity)
    {
      '@context' => 'https://www.w3.org/ns/activitystreams',
      'id' => activity.ap_id,
      'type' => 'Delete',
      'actor' => activity.actor.ap_id,
      'object' => activity.target_ap_id,
      'published' => activity.published_at.iso8601
    }
  end

  def build_generic_activity_data(activity)
    {
      '@context' => 'https://www.w3.org/ns/activitystreams',
      'id' => activity.ap_id,
      'type' => activity.activity_type,
      'actor' => activity.actor.ap_id,
      'published' => activity.published_at.iso8601
    }
  end

  def build_audience(object, type)
    case object.visibility
    when 'public'
      build_public_audience(type)
    when 'unlisted'
      build_unlisted_audience(object, type)
    when 'followers_only'
      build_followers_audience(object, type)
    when 'direct'
      build_direct_audience(type)
    else
      []
    end
  end

  def build_public_audience(type)
    case type
    when :to
      ['https://www.w3.org/ns/activitystreams#Public']
    when :cc
      [@activity.actor.followers_url]
    end
  end

  def build_unlisted_audience(object, type)
    case type
    when :to
      [object.actor.followers_url]
    when :cc
      ['https://www.w3.org/ns/activitystreams#Public']
    end
  end

  def build_followers_audience(object, type)
    case type
    when :to
      [object.actor.followers_url]
    when :cc
      []
    end
  end

  def build_direct_audience(_type)
    # DMの場合は宛先を動的に設定（将来実装）
    []
  end

  def build_attachments(object)
    object.media_attachments.map do |attachment|
      {
        'type' => 'Document',
        'mediaType' => attachment.mime_type,
        'url' => attachment.file_url,
        'name' => attachment.description || attachment.filename,
        'width' => attachment.width,
        'height' => attachment.height,
        'blurhash' => attachment.blurhash
      }.compact
    end
  end

  def build_tags(_object)
    # TODO: ハッシュタグ・メンション実装時に追加
    []
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
