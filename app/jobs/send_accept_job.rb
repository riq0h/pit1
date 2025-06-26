# frozen_string_literal: true

class SendAcceptJob < ApplicationJob
  require 'net/http'
  require 'timeout'

  queue_as :default

  def perform(follow)
    Rails.logger.info "✅ Sending Accept activity for follow #{follow.id}"

    # 対応するActivity recordを取得
    activity_record = find_accept_activity(follow)

    accept_activity = build_accept_activity(follow)
    result = send_accept_activity(accept_activity, follow)

    handle_response(result, follow, activity_record)
  rescue StandardError => e
    handle_error(e, 'Accept job error')
  end

  private

  def build_accept_activity(follow)
    {
      '@context' => Rails.application.config.activitypub.context_url,
      'type' => 'Accept',
      'id' => "#{follow.target_actor.ap_id}#accepts/follows/#{follow.id}",
      'actor' => follow.target_actor.ap_id,
      'object' => {
        'type' => 'Follow',
        'id' => follow.follow_activity_ap_id,
        'actor' => follow.actor.ap_id,
        'object' => follow.target_actor.ap_id
      }
    }
  end

  def send_accept_activity(activity, follow)
    sender = ActivitySender.new
    sender.send_activity(
      activity: activity,
      target_inbox: follow.actor.inbox_url,
      signing_actor: follow.target_actor
    )
  end

  def find_accept_activity(follow)
    Activity.find_by(
      activity_type: 'Accept',
      actor: follow.target_actor,
      target_ap_id: follow.ap_id
    )
  end

  def handle_response(response, follow, activity_record)
    if response[:success]
      follow.update!(accepted: true)
      update_activity_delivery_status(activity_record, true, response)
      Rails.logger.info "✅ Accept sent successfully for follow #{follow.id}"
    else
      update_activity_delivery_status(activity_record, false, response)
      handle_failure(follow, activity_record, response)
    end
  end

  def handle_failure(follow, activity_record, response)
    error_details = response[:error] || '未知のエラー'
    Rails.logger.error "❌ Failed to send Accept for follow #{follow.id}: #{error_details}"

    if executions < 3
      retry_job(wait: 30.seconds)
    else
      Rails.logger.error "💥 Accept sending failed permanently for follow #{follow.id}"
      mark_activity_failed(activity_record, error_details)
    end
  end

  def update_activity_delivery_status(activity_record, success, response)
    return unless activity_record

    if success
      activity_record.update!(
        delivered: true,
        delivered_at: Time.current,
        delivery_attempts: activity_record.delivery_attempts + 1
      )
    else
      error_msg = response[:error] || 'HTTP request failed'
      activity_record.update!(
        delivery_attempts: activity_record.delivery_attempts + 1,
        last_delivery_error: error_msg
      )
    end
  end

  def mark_activity_failed(activity_record, error_details = nil)
    return unless activity_record

    final_error = error_details || "Delivery failed after #{executions} attempts"
    activity_record.update!(
      delivered: false,
      last_delivery_error: final_error
    )
  end
end
