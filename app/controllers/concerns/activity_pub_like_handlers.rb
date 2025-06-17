# frozen_string_literal: true

module ActivityPubLikeHandlers
  extend ActiveSupport::Concern

  private

  # Like Activity処理
  def handle_like_activity
    Rails.logger.info '❤️ Processing Like activity'

    object_ap_id = extract_like_object_id
    return head(:accepted) unless object_ap_id

    target_object = find_target_object(object_ap_id)
    return head(:accepted) unless target_object

    create_or_update_like(target_object)
    head :accepted
  end

  def extract_like_object_id
    object = @activity['object']
    object.is_a?(Hash) ? object['id'] : object
  end

  def create_or_update_like(target_object)
    # 既存のLikeをチェック（ActivityとFavourite両方）
    existing_like_activity = target_object.activities.find_by(
      actor: @sender,
      activity_type: 'Like'
    )

    existing_favourite = Favourite.find_by(
      actor: @sender,
      object: target_object
    )

    if existing_like_activity || existing_favourite
      Rails.logger.info "❤️ Like already exists: Activity #{existing_like_activity&.id}, Favourite #{existing_favourite&.id}"
      return
    end

    ActiveRecord::Base.transaction do
      # 新しいLike Activityを作成
      like_activity = target_object.activities.create!(
        actor: @sender,
        activity_type: 'Like',
        ap_id: @activity['id'],
        target_ap_id: target_object.ap_id, # target_ap_idを設定
        published_at: Time.current,
        local: false,
        processed: true
      )

      # 対応するFavouriteレコードを作成
      favourite = Favourite.create!(
        actor: @sender,
        object: target_object,
        ap_id: @activity['id']
      )

      Rails.logger.info "❤️ Like created: Activity #{like_activity.id}, Favourite #{favourite.id}, favourites_count updated to #{target_object.reload.favourites_count}"
    end
  end
end
