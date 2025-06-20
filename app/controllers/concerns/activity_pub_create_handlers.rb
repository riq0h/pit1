# frozen_string_literal: true

require_relative '../../services/html_stripper'

module ActivityPubCreateHandlers
  extend ActiveSupport::Concern
  include ActivityPubMediaHandler
  include ActivityPubConversationHandler

  private

  def handle_create_activity
    Rails.logger.info '📝 Processing Create activity'

    object_data = @activity['object']

    unless valid_create_object?(object_data)
      Rails.logger.warn '⚠️ Invalid object in Create activity'
      head :accepted
      return
    end

    return handle_existing_object(object_data) if object_exists?(object_data)

    create_new_object(object_data)
  end

  def valid_create_object?(object_data)
    object_data.is_a?(Hash)
  end

  def object_exists?(object_data)
    ActivityPubObject.find_by(ap_id: object_data['id'])
  end

  def handle_existing_object(object_data)
    Rails.logger.warn "⚠️ Object already exists: #{object_data['id']}"
    head :accepted
  end

  def create_new_object(object_data)
    object = ActivityPubObject.create!(build_object_attributes(object_data))

    handle_media_attachments(object, object_data)
    handle_mentions(object, object_data)
    handle_emojis(object, object_data)
    handle_direct_message_conversation(object, object_data) if object.visibility == 'direct'
    update_reply_count_if_needed(object)

    Rails.logger.info "📝 Object created: #{object.id}"
    head :accepted
  end

  def build_object_attributes(object_data)
    {
      ap_id: object_data['id'],
      actor: @sender,
      object_type: object_data['type'] || 'Note',
      content: object_data['content'],
      content_plaintext: ActivityPub::HtmlStripper.strip(object_data['content']),
      summary: object_data['summary'],
      url: object_data['url'],
      in_reply_to_ap_id: object_data['inReplyTo'],
      conversation_ap_id: object_data['conversation'],
      published_at: parse_published_time(object_data['published']),
      sensitive: object_data['sensitive'] || false,
      visibility: determine_visibility(object_data),
      raw_data: object_data.to_json,
      local: false
    }
  end

  def parse_published_time(published_str)
    return Time.current unless published_str

    Time.zone.parse(published_str)
  end

  def determine_visibility(object_data)
    to = Array(object_data['to'])
    cc = Array(object_data['cc'])

    return 'public' if to.include?('https://www.w3.org/ns/activitystreams#Public')
    return 'unlisted' if cc.include?('https://www.w3.org/ns/activitystreams#Public')
    return 'private' if to.include?(@target_actor.followers_url)

    'direct'
  end

  def handle_mentions(object, object_data)
    tags = Array(object_data['tag'])
    mention_tags = tags.select { |tag| tag['type'] == 'Mention' }

    mention_tags.each do |mention_tag|
      href = mention_tag['href']
      next unless href

      # ローカルアクターかチェック
      mentioned_actor = Actor.find_by(ap_id: href)
      next unless mentioned_actor&.local?

      # Mentionレコード作成
      Mention.create!(
        object: object,
        actor: mentioned_actor,
        ap_id: "#{object.ap_id}#mention-#{mentioned_actor.id}"
      )

      Rails.logger.info "💬 Mention created: #{mentioned_actor.username}"
    end
  rescue StandardError => e
    Rails.logger.error "Failed to handle mentions: #{e.message}"
  end

  def handle_emojis(object, object_data)
    tags = Array(object_data['tag'])
    emoji_tags = tags.select { |tag| tag['type'] == 'Emoji' }

    emoji_tags.each do |emoji_tag|
      shortcode = emoji_tag['name']&.gsub(/^:|:$/, '')
      icon_url = emoji_tag.dig('icon', 'url')

      next unless shortcode.present? && icon_url.present?

      remote_domain = extract_domain_from_uri(object.ap_id)
      next unless remote_domain

      existing_emoji = CustomEmoji.find_by(shortcode: shortcode, domain: remote_domain)

      next if existing_emoji

      CustomEmoji.create!(
        shortcode: shortcode,
        domain: remote_domain,
        image_url: icon_url,
        visible_in_picker: false,
        disabled: false
      )

      Rails.logger.info "🎨 Remote emoji created: :#{shortcode}: from #{remote_domain}"
    end
  rescue StandardError => e
    Rails.logger.error "Failed to handle emojis: #{e.message}"
  end

  def extract_domain_from_uri(uri)
    return nil unless uri

    parsed_uri = URI.parse(uri)
    parsed_uri.host
  rescue URI::InvalidURIError
    nil
  end

  def update_reply_count_if_needed(object)
    return unless object.in_reply_to_ap_id

    parent_object = ActivityPubObject.find_by(ap_id: object.in_reply_to_ap_id)
    return unless parent_object

    parent_object.increment!(:replies_count)
    Rails.logger.info "💬 Reply count updated for #{parent_object.ap_id}: #{parent_object.replies_count}"
  end
end
