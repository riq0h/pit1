# frozen_string_literal: true

module SearchStatusSerializer
  def serialized_status(status)
    base_status_data(status).merge(
      additional_status_data(status)
    )
  end

  def serialized_media_attachments(status)
    status.media_attachments.map do |attachment|
      build_media_attachment_data(attachment)
    end
  end

  private

  def base_status_data(status)
    {
      id: status.id.to_s,
      created_at: status.published_at.iso8601,
      in_reply_to_id: nil,
      in_reply_to_account_id: nil,
      sensitive: status.sensitive || false,
      spoiler_text: status.summary || '',
      visibility: status.visibility || 'public',
      language: 'ja',
      uri: status.ap_id,
      url: status.public_url
    }
  end

  def additional_status_data(status)
    {
      replies_count: 0,
      reblogs_count: 0,
      favourites_count: 0,
      reblogged: false,
      favourited: false,
      muted: false,
      bookmarked: false,
      pinned: false,
      content: status.content || '',
      reblog: nil,
      application: nil,
      account: serialized_account(status.actor),
      media_attachments: serialized_media_attachments(status),
      mentions: [],
      tags: [],
      emojis: [],
      card: nil,
      poll: serialize_poll_for_search(status)
    }
  end

  def build_media_attachment_data(attachment)
    {
      id: attachment.id.to_s,
      type: attachment.media_type,
      url: attachment.remote_url || attachment.url,
      preview_url: attachment.remote_url || attachment.url,
      remote_url: attachment.remote_url,
      description: attachment.description,
      blurhash: attachment.blurhash,
      meta: build_media_meta_data(attachment)
    }
  end

  def build_media_meta_data(attachment)
    {
      original: {
        width: attachment.width,
        height: attachment.height,
        size: "#{attachment.width}x#{attachment.height}",
        aspect: calculate_aspect_ratio(attachment)
      }
    }
  end

  def calculate_aspect_ratio(attachment)
    return nil unless attachment.width && attachment.height

    attachment.width.to_f / attachment.height
  end

  def serialize_poll_for_search(status)
    return nil unless status.poll

    poll = status.poll
    {
      id: poll.id.to_s,
      expires_at: poll.expires_at.iso8601,
      expired: poll.expired?,
      multiple: poll.multiple,
      votes_count: poll.votes_count,
      voters_count: poll.multiple ? poll.voters_count : poll.votes_count,
      options: poll.option_titles.map.with_index { |title, index| { title: title, votes_count: poll.option_votes_count(index) } },
      emojis: [],
      voted: false,
      own_votes: []
    }
  end
end
