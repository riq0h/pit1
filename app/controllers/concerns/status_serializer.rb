# frozen_string_literal: true

module StatusSerializer
  extend ActiveSupport::Concern

  private

  def base_status_data(status)
    {
      id: status.id.to_s,
      created_at: status.published_at.iso8601,
      uri: status.ap_id,
      url: status.public_url,
      account: serialized_account(status.actor)
    }
  end

  def interaction_data(status)
    {
      replies_count: replies_count(status),
      reblogs_count: status.reblogs_count || 0,
      favourites_count: status.favourites_count || 0,
      favourited: favourited_by_current_user?(status),
      reblogged: reblogged_by_current_user?(status)
    }
  end

  def content_data(status)
    parsed_content = parse_content_with_emojis(status.content || '')

    {
      content: parsed_content,
      sensitive: status.sensitive || false,
      spoiler_text: status.summary || '',
      visibility: status.visibility || 'public',
      language: 'ja'
    }
  end

  def metadata_data(status)
    {
      in_reply_to_id: in_reply_to_id(status),
      in_reply_to_account_id: in_reply_to_account_id(status),
      media_attachments: serialized_media_attachments(status),
      mentions: serialized_mentions(status),
      tags: serialized_tags(status),
      reblog: nil,
      emojis: serialized_emojis(status),
      card: nil,
      poll: nil
    }
  end

  def parse_content_with_emojis(content)
    return content if content.blank?

    EmojiParser.parse_text(content)
  end

  def serialized_emojis(status)
    return [] if status.content.blank?

    emojis = EmojiParser.extract_emojis(status.content)
    emojis.map(&:to_activitypub)
  end
end
