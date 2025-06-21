# frozen_string_literal: true

module StatusSerializationHelper
  extend ActiveSupport::Concern
  include AccountSerializer
  include MediaSerializer
  include MentionTagSerializer
  include TextLinkingHelper
  include StatusSerializer

  private

  def serialized_status(status)
    base_status_data(status).merge(
      interaction_data(status),
      content_data(status),
      metadata_data(status)
    )
  end

  def base_status_data(status)
    {
      id: status.id.to_s,
      created_at: status.published_at&.iso8601 || status.created_at.iso8601,
      edited_at: status.edited_at&.iso8601,
      uri: status.ap_id,
      url: status.url || status.ap_id,
      visibility: status.visibility,
      language: status.language,
      sensitive: status.sensitive?
    }
  end

  def interaction_data(status)
    {
      in_reply_to_id: in_reply_to_id(status),
      in_reply_to_account_id: in_reply_to_account_id(status),
      replies_count: replies_count(status),
      reblogs_count: status.reblogs_count || 0,
      favourites_count: status.favourites_count || 0,
      favourited: favourited_by_current_user?(status),
      reblogged: reblogged_by_current_user?(status),
      bookmarked: bookmarked_by_current_user?(status),
      pinned: pinned_by_current_user?(status)
    }
  end

  def content_data(status)
    {
      spoiler_text: status.summary || '',
      content: parse_content_links_only(status.content || ''),
      account: serialized_account(status.actor),
      reblog: nil
    }
  end

  def metadata_data(status)
    {
      media_attachments: serialized_media_attachments(status),
      mentions: serialized_mentions(status),
      tags: serialized_tags(status),
      emojis: serialized_emojis(status),
      card: nil,
      poll: nil
    }
  end

  def in_reply_to_id(status)
    return nil if status.in_reply_to_ap_id.blank?

    in_reply_to = ActivityPubObject.find_by(ap_id: status.in_reply_to_ap_id)
    in_reply_to&.id&.to_s
  end

  def in_reply_to_account_id(status)
    return nil if status.in_reply_to_ap_id.blank?

    in_reply_to = ActivityPubObject.find_by(ap_id: status.in_reply_to_ap_id)
    return nil unless in_reply_to&.actor

    in_reply_to.actor.id.to_s
  end

  def replies_count(status)
    ActivityPubObject.where(in_reply_to_ap_id: status.ap_id).count
  end

  def favourited_by_current_user?(status)
    return false unless current_user

    current_user.favourites.exists?(object: status)
  end

  def reblogged_by_current_user?(status)
    return false unless current_user

    current_user.reblogs.exists?(object: status)
  end

  def bookmarked_by_current_user?(status)
    return false unless current_user

    current_user.bookmarks.exists?(object: status)
  end

  def pinned_by_current_user?(status)
    return false unless current_user

    current_user.pinned_statuses.exists?(object: status)
  end
end
