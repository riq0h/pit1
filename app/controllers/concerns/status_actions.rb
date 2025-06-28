# frozen_string_literal: true

module StatusActions
  extend ActiveSupport::Concern

  private

  def create_like_activity(status)
    # Like アクティビティを作成
    activity = Activity.create!(
      ap_id: "#{Rails.application.config.activitypub.base_url}/#{Letter::Snowflake.generate}",
      activity_type: 'Like',
      actor: current_user,
      target_ap_id: status.ap_id,
      object_ap_id: nil,
      published_at: Time.current,
      local: true
    )

    # ジョブをキューに追加
    return if status.actor.inbox_url.blank?

    SendActivityJob.perform_later(activity.id, [status.actor.inbox_url])
  end

  def create_undo_like_activity(status, _favourite)
    like_activity = Activity.find_by(
      activity_type: 'Like',
      actor: current_user,
      target_ap_id: status.ap_id
    )

    return unless like_activity

    # Undo アクティビティを作成
    undo_activity = Activity.create!(
      ap_id: "#{Rails.application.config.activitypub.base_url}/#{Letter::Snowflake.generate}",
      activity_type: 'Undo',
      actor: current_user,
      target_ap_id: like_activity.ap_id,
      object_ap_id: nil,
      published_at: Time.current,
      local: true
    )

    # 元のLikeアクティビティを削除
    like_activity.destroy

    # ジョブをキューに追加
    return if status.actor.inbox_url.blank?

    SendActivityJob.perform_later(undo_activity.id, [status.actor.inbox_url])
  end

  def create_announce_activity(status)
    # Announce アクティビティを作成
    activity = Activity.create!(
      ap_id: "#{Rails.application.config.activitypub.base_url}/#{Letter::Snowflake.generate}",
      activity_type: 'Announce',
      actor: current_user,
      target_ap_id: status.ap_id,
      object_ap_id: nil,
      published_at: Time.current,
      local: true
    )

    # ジョブをキューに追加
    return if status.actor.inbox_url.blank?

    SendActivityJob.perform_later(activity.id, [status.actor.inbox_url])
  end

  def create_undo_announce_activity(status, _reblog)
    announce_activity = Activity.find_by(
      activity_type: 'Announce',
      actor: current_user,
      target_ap_id: status.ap_id
    )

    return unless announce_activity

    # Undo アクティビティを作成
    undo_activity = Activity.create!(
      ap_id: "#{Rails.application.config.activitypub.base_url}/#{Letter::Snowflake.generate}",
      activity_type: 'Undo',
      actor: current_user,
      target_ap_id: announce_activity.ap_id,
      object_ap_id: nil,
      published_at: Time.current,
      local: true
    )

    # 元のAnnounceアクティビティを削除
    announce_activity.destroy

    # ジョブをキューに追加
    return if status.actor.inbox_url.blank?

    SendActivityJob.perform_later(undo_activity.id, [status.actor.inbox_url])
  end
end
