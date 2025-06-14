# frozen_string_literal: true

module ActivityPubFollowHandlers
  extend ActiveSupport::Concern

  private

  # Follow Activity処理
  def handle_follow_activity
    Rails.logger.info '👥 Processing Follow request'

    existing_follow = find_existing_follow

    if existing_follow
      if existing_follow.accepted?
        Rails.logger.warn '⚠️ Follow already accepted'
      else
        # 未承認のフォローを自動承認
        Rails.logger.info '🔄 Re-accepting pending follow'
        existing_follow.accept!
        Rails.logger.info "✅ Follow re-accepted: #{existing_follow.id}"
      end
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
      follow_activity_ap_id: @activity['id']
    )

    # 自動承認（Follow モデルのaccept!メソッドを使用）
    follow.accept!

    Rails.logger.info "✅ Follow auto-accepted: #{follow.id}"
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
    # まず正確なIDマッチを試行
    follow = Follow.find_by(
      actor: @sender,
      target_actor: @target_actor,
      follow_activity_ap_id: object['id']
    )

    # IDが一致しない場合は、同じアクター間の最新のフォローを検索
    unless follow
      Rails.logger.info "↩️ Exact ID not found, searching for any follow from #{@sender.ap_id}"
      follow = Follow.find_by(
        actor: @sender,
        target_actor: @target_actor
      )
    end

    return unless follow

    follow.destroy!
    Rails.logger.info "↩️ Follow undone: #{follow.id} (requested: #{object['id']})"
  end

  def extract_activity_id(object)
    object.is_a?(Hash) ? object['id'] : object
  end
end
