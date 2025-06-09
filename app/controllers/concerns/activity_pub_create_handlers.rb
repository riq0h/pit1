# frozen_string_literal: true

module ActivityPubCreateHandlers
  extend ActiveSupport::Concern

  private

  # Create Activity処理
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
      raw_data: object_data,
      local: false
    }
  end

  def parse_published_time(published_str)
    return Time.current unless published_str

    Time.zone.parse(published_str)
  end

  # 可視性判定
  def determine_visibility(object_data)
    to = Array(object_data['to'])
    cc = Array(object_data['cc'])

    return 'public' if to.include?('https://www.w3.org/ns/activitystreams#Public')
    return 'unlisted' if cc.include?('https://www.w3.org/ns/activitystreams#Public')
    return 'private' if to.include?(@target_actor.followers_url)

    'direct'
  end
end
