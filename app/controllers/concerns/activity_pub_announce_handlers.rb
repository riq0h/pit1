# frozen_string_literal: true

module ActivityPubAnnounceHandlers
  extend ActiveSupport::Concern

  private

  # Announce Activity処理（ブースト）
  def handle_announce_activity
    Rails.logger.info '📢 Processing Announce activity'

    object_ap_id = extract_announce_object_id
    return head(:accepted) unless object_ap_id

    target_object = find_target_object(object_ap_id)
    return head(:accepted) unless target_object

    create_or_update_announce(target_object)
    head :accepted
  end

  def extract_announce_object_id
    object = @activity['object']
    object.is_a?(Hash) ? object['id'] : object
  end

  def create_or_update_announce(target_object)
    # 既存のAnnounce（Reblog）をチェック
    existing_reblog = Reblog.find_by(
      actor: @sender,
      object: target_object
    )

    if existing_reblog
      Rails.logger.info "📢 Announce already exists: #{existing_reblog.id}"
      return
    end

    # 新しいReblogを作成
    reblog = Reblog.create!(
      actor: @sender,
      object: target_object
    )

    # ActivityPub Activity記録も作成
    target_object.activities.create!(
      actor: @sender,
      activity_type: 'Announce',
      ap_id: @activity['id'],
      published_at: Time.current,
      local: false,
      processed: true
    )

    Rails.logger.info "📢 Announce created: #{reblog.id}, reblogs_count updated to #{target_object.reload.reblogs_count}"
  end
end
