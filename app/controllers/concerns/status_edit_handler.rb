# frozen_string_literal: true

module StatusEditHandler
  extend ActiveSupport::Concern

  private

  def build_edit_params
    edit_params = params.permit(:status, :spoiler_text, :language, :sensitive)
    edit_params[:media_ids] = @media_ids if @media_ids&.any?
    edit_params
  end

  def process_mentions_and_tags_for_edit
    return unless edit_params[:status]

    content = edit_params[:status]

    # メンションの処理
    mentions = extract_mentions(content)
    edit_params[:mentions] = mentions.map(&:username).uniq if mentions.any?

    # ハッシュタグの処理
    hashtags = extract_hashtags(content)
    edit_params[:tags] = hashtags.map(&:name).uniq if hashtags.any?
  end

  def build_current_version
    {
      account: serialized_account(@status.actor),
      content: @status.content || '',
      created_at: @status.published_at.iso8601,
      emojis: [], # TODO: カスタム絵文字対応
      media_attachments: @status.media_attachments.map { |media| serialized_media_attachment(media) },
      poll: @status.poll ? serialized_poll(@status.poll) : nil,
      sensitive: @status.sensitive || false,
      spoiler_text: @status.summary || '',
      tags: @status.tags.map { |tag| serialized_tag(tag) },
      mentions: @status.mentions.map { |mention| serialized_mention(mention) }
    }
  end

  def build_edit_version(edit)
    edit_data = JSON.parse(edit.data || '{}')

    {
      account: serialized_account(@status.actor),
      content: edit_data['content'] || '',
      created_at: edit.created_at.iso8601,
      emojis: edit_data['emojis'] || [],
      media_attachments: (edit_data['media_attachments'] || []).map do |media|
        serialized_media_attachment_from_data(media)
      end,
      poll: edit_data['poll'] ? serialized_poll_from_data(edit_data['poll']) : nil,
      sensitive: edit_data['sensitive'] || false,
      spoiler_text: edit_data['spoiler_text'] || '',
      tags: (edit_data['tags'] || []).map { |tag| serialized_tag_from_data(tag) },
      mentions: (edit_data['mentions'] || []).map do |mention|
        serialized_mention_from_data(mention)
      end
    }
  end

  def serialized_media_attachment_from_data(media_data)
    {
      id: media_data['id'],
      type: media_data['type'],
      url: media_data['url'],
      preview_url: media_data['preview_url'],
      description: media_data['description'],
      meta: media_data['meta'] || {}
    }
  end

  def serialized_poll_from_data(poll_data)
    {
      id: poll_data['id'],
      expires_at: poll_data['expires_at'],
      expired: poll_data['expired'] || false,
      multiple: poll_data['multiple'] || false,
      votes_count: poll_data['votes_count'] || 0,
      options: poll_data['options'] || [],
      voted: poll_data['voted'] || false,
      own_votes: poll_data['own_votes'] || []
    }
  end

  def serialized_tag_from_data(tag_data)
    {
      name: tag_data['name'],
      url: tag_data['url']
    }
  end

  def serialized_mention_from_data(mention_data)
    {
      id: mention_data['id'],
      username: mention_data['username'],
      acct: mention_data['acct'],
      url: mention_data['url']
    }
  end
end
