# frozen_string_literal: true

class UndoProcessor
  def initialize(target_activity)
    @target_activity = target_activity
  end

  def process!
    case @target_activity.activity_type
    when 'Follow'
      undo_follow
    when 'Like'
      undo_like
    when 'Announce'
      undo_announce
    end
  end

  private

  attr_reader :target_activity

  def undo_follow
    follow = Follow.find_by(follow_activity_ap_id: target_activity.ap_id)
    follow&.destroy
  end

  def undo_like
    return unless target_activity.target_ap_id

    target_obj = ActivityPubObject.find_by(ap_id: target_activity.target_ap_id)
    return unless target_obj
    return unless target_obj.favourites_count.positive?

    # バリデーションを含む安全な更新
    target_obj.update!(favourites_count: target_obj.favourites_count - 1)
  end

  def undo_announce
    return unless target_activity.target_ap_id

    target_obj = ActivityPubObject.find_by(ap_id: target_activity.target_ap_id)
    return unless target_obj
    return unless target_obj.reblogs_count.positive?

    # バリデーションを含む安全な更新
    target_obj.update!(reblogs_count: target_obj.reblogs_count - 1)
  end
end
