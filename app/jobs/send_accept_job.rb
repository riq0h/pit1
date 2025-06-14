# frozen_string_literal: true

class SendAcceptJob < ApplicationJob
  queue_as :default

  def perform(follow)
    Rails.logger.info "✅ Sending Accept activity for follow #{follow.id}"

    accept_activity = build_accept_activity(follow)
    success = send_accept_activity(accept_activity, follow)

    handle_response(success, follow)
  rescue StandardError => e
    handle_error(e, follow)
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

  def handle_response(success, follow)
    if success
      follow.update!(accepted: true)
      Rails.logger.info "✅ Accept sent successfully for follow #{follow.id}"
    else
      handle_failure(follow)
    end
  end

  def handle_failure(follow)
    Rails.logger.error "❌ Failed to send Accept for follow #{follow.id}"

    if executions < 3
      retry_job(wait: 30.seconds)
    else
      Rails.logger.error "💥 Accept sending failed permanently for follow #{follow.id}"
    end
  end

  def handle_error(error, _follow)
    Rails.logger.error "💥 Accept job error: #{error.message}"
    Rails.logger.error error.backtrace.first(3).join("\n")

    raise error unless executions < 3

    retry_job(wait: 1.minute)
  end
end
