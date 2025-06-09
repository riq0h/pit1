# frozen_string_literal: true

module ActivityPubHandlers
  extend ActiveSupport::Concern

  private

  # Follow Activity処理
  def handle_follow_activity
    Rails.logger.info '👥 Processing Follow request'

    existing_follow = find_existing_follow

    if existing_follow
      Rails.logger.warn '⚠️ Follow already exists'
      head :accepted
      return
    end

    create_follow_request
  end

  def find_existing_follow
    Follow.find_by(
      actor: @sender,
      target_actor: @target_actor
    )
  end

  def create_follow_request
    follow = Follow.create!(
      actor: @sender,
      target_actor: @target_actor,
      ap_id: @activity['id'],
      follow_activity_ap_id: @activity['id'],
      accepted: false # 手動承認
    )

    ActivityPub::SendAcceptJob.perform_later(follow)
    Rails.logger.info "✅ Follow created: #{follow.id}"
    head :accepted
  end

  # Accept Activity処理
  def handle_accept_activity
    Rails.logger.info '✅ Processing Accept activity'

    object = @activity['object']
    follow_ap_id = extract_activity_id(object)
    follow = Follow.find_by(follow_activity_ap_id: follow_ap_id)

    if follow
      follow.update!(accepted: true)
      Rails.logger.info "✅ Follow accepted: #{follow.id}"
    else
      Rails.logger.warn "⚠️ Follow not found for Accept: #{follow_ap_id}"
    end

    head :accepted
  end

  # Reject Activity処理
  def handle_reject_activity
    Rails.logger.info '❌ Processing Reject activity'

    object = @activity['object']
    follow_ap_id = extract_activity_id(object)
    follow = Follow.find_by(follow_activity_ap_id: follow_ap_id)

    if follow
      follow.destroy!
      Rails.logger.info "❌ Follow rejected and deleted: #{follow_ap_id}"
    else
      Rails.logger.warn "⚠️ Follow not found for Reject: #{follow_ap_id}"
    end

    head :accepted
  end

  # Undo Activity処理
  def handle_undo_activity
    Rails.logger.info '↩️ Processing Undo activity'

    object = @activity['object']

    case object['type']
    when 'Follow'
      handle_undo_follow(object)
    else
      Rails.logger.warn "⚠️ Unsupported Undo object: #{object['type']}"
    end

    head :accepted
  end

  def handle_undo_follow(object)
    follow = Follow.find_by(
      actor: @sender,
      target_actor: @target_actor,
      follow_activity_ap_id: object['id']
    )

    return unless follow

    follow.destroy!
    Rails.logger.info "↩️ Follow undone: #{object['id']}"
  end

  # Announce Activity処理（ブースト）
  def handle_announce_activity
    Rails.logger.info '📢 Processing Announce activity'

    # TODO: ブースト機能実装時に詳細化
    Rails.logger.info '📢 Announce processed (basic logging only)'
    head :accepted
  end

  # Like Activity処理
  def handle_like_activity
    Rails.logger.info '❤️ Processing Like activity'

    # TODO: いいね機能実装時に詳細化
    Rails.logger.info '❤️ Like processed (basic logging only)'
    head :accepted
  end

  def extract_activity_id(object)
    object.is_a?(Hash) ? object['id'] : object
  end
end
