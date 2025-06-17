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

    existing_announce_activity = target_object.activities.find_by(
      actor: @sender,
      activity_type: 'Announce'
    )

    if existing_reblog || existing_announce_activity
      Rails.logger.info "📢 Announce already exists: Reblog #{existing_reblog&.id}, Activity #{existing_announce_activity&.id}"
      return
    end

    ActiveRecord::Base.transaction do
      # 新しいReblogを作成
      reblog = Reblog.create!(
        actor: @sender,
        object: target_object,
        ap_id: @activity['id']
      )

      # ActivityPub Activity記録も作成
      announce_activity = target_object.activities.create!(
        actor: @sender,
        activity_type: 'Announce',
        ap_id: @activity['id'],
        target_ap_id: target_object.ap_id, # target_ap_idを設定
        published_at: Time.current,
        local: false,
        processed: true
      )

      Rails.logger.info "📢 Announce created: Reblog #{reblog.id}, Activity #{announce_activity.id}, reblogs_count updated to #{target_object.reload.reblogs_count}"
    end
  end
end
