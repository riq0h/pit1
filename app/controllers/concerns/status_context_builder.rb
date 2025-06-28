# frozen_string_literal: true

module StatusContextBuilder
  extend ActiveSupport::Concern

  private

  def build_ancestors(status)
    return [] unless status.in_reply_to_ap_id

    ancestors = []
    current_status = status

    # 祖先を遡って収集（最大深度制限）
    depth = 0
    max_depth = 10

    while current_status.in_reply_to_ap_id && depth < max_depth
      parent = ActivityPubObject.find_by(ap_id: current_status.in_reply_to_ap_id)
      break unless parent

      ancestors.unshift(parent)
      current_status = parent
      depth += 1
    end

    ancestors
  end

  def build_descendants(status)
    # 直接的な返信を取得
    direct_replies = ActivityPubObject.where(in_reply_to_ap_id: status.ap_id)
                                      .includes(:actor, :media_attachments, :mentions, :tags, :poll)
                                      .order(:published_at)

    descendants = []

    # 各返信を再帰的に処理（最大深度制限）
    direct_replies.each do |reply|
      descendants << reply
      descendants.concat(build_descendants_recursive(reply, 1, 5))
    end

    descendants
  end

  def build_descendants_recursive(status, current_depth, max_depth)
    return [] if current_depth >= max_depth

    replies = ActivityPubObject.where(in_reply_to_ap_id: status.ap_id)
                               .includes(:actor, :media_attachments, :mentions, :tags, :poll)
                               .order(:published_at)

    descendants = []
    replies.each do |reply|
      descendants << reply
      descendants.concat(build_descendants_recursive(reply, current_depth + 1, max_depth))
    end

    descendants
  end
end
