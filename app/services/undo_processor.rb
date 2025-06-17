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

    ActiveRecord::Base.transaction do
      # Favouriteレコードを削除
      favourite = Favourite.find_by(
        actor: target_activity.actor,
        object: target_obj
      )
      favourite&.destroy

      # Like Activityを削除
      target_activity.destroy

      Rails.logger.info "❤️ Like undone: Activity #{target_activity.id} deleted, Favourite #{favourite&.id} deleted"
    end
  end

  def undo_announce
    return unless target_activity.target_ap_id

    target_obj = ActivityPubObject.find_by(ap_id: target_activity.target_ap_id)
    return unless target_obj

    ActiveRecord::Base.transaction do
      # Reblogレコードを削除
      reblog = Reblog.find_by(
        actor: target_activity.actor,
        object: target_obj
      )
      reblog&.destroy

      # Announce Activityを削除
      target_activity.destroy

      Rails.logger.info "📢 Announce undone: Activity #{target_activity.id} deleted, Reblog #{reblog&.id} deleted"
    end
  end
end
