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
    # 既存のLikeをチェック
    existing_like = target_object.activities.find_by(
      actor: @sender,
      activity_type: 'Like'
    )

    if existing_like
      Rails.logger.info "❤️ Like already exists: #{existing_like.id}"
      return
    end

    # 新しいLikeを作成
    like = target_object.activities.create!(
      actor: @sender,
      activity_type: 'Like',
      ap_id: @activity['id'],
      published_at: Time.current,
      local: false,
      processed: true
    )

    # お気に入り数を更新
    target_object.increment!(:favourites_count)

    Rails.logger.info "❤️ Like created: #{like.id}, favourites_count updated to #{target_object.favourites_count}"
  end
end
