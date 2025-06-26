# frozen_string_literal: true

module ActivityPubObjectHandlers
  extend ActiveSupport::Concern
  include ActivityPubVisibilityHelper
  include ActivityPubMediaHandler

  private

  # Update Activity処理
  def handle_update_activity
    Rails.logger.info '📝 Processing Update activity'

    object_data = @activity['object']

    if object_data['type'] == 'Person'
      update_actor_profile(object_data)
    else
      update_object_content(object_data)
    end

    head :accepted
  end

  def update_actor_profile(object_data)
    @sender.update!(
      display_name: object_data['name'],
      note: object_data['summary'],
      icon_url: object_data.dig('icon', 'url'),
      header_url: object_data.dig('image', 'url'),
      raw_data: object_data.to_json
    )
    Rails.logger.info "👤 Actor updated: #{@sender.username}"
  end

  def update_object_content(object_data)
    object = ActivityPubObject.find_by(ap_id: object_data['id'])

    return unless object&.actor == @sender

    object.update!(build_update_attributes(object_data))

    # メディア添付の更新処理
    update_object_attachments(object, object_data)

    Rails.logger.info "📝 Object updated: #{object.id}"
  end

  def build_update_attributes(object_data)
    update_attrs = {
      content: object_data['content'],
      content_plaintext: ActivityPub::HtmlStripper.strip(object_data['content']),
      summary: object_data['summary'],
      sensitive: object_data['sensitive'] || false,
      raw_data: object_data.to_json
    }

    # updated フィールドがある場合は edited_at を設定
    if object_data['updated'].present?
      update_attrs[:edited_at] = Time.zone.parse(object_data['updated'])
      Rails.logger.info "📝 Setting edited_at to #{object_data['updated']}"
    end

    update_attrs
  end

  def update_object_attachments(object, object_data)
    attachments = object_data['attachment']
    return unless attachments.is_a?(Array)

    Rails.logger.info "📎 Updating #{attachments.length} attachments for object #{object.id}"

    # 既存のメディア添付を削除
    object.media_attachments.destroy_all

    # 新しいメディア添付を作成
    attachments.each do |attachment|
      next unless attachment.is_a?(Hash) && attachment['type'] == 'Document'

      create_remote_media_attachment(object, attachment)
    end
  end

  def create_remote_media_attachment(object, attachment_data)
    url = attachment_data['url']
    file_name = extract_filename_from_url(url)
    media_type = determine_media_type_from_content_type(attachment_data['mediaType'])

    media_attrs = {
      actor: object.actor,
      object: object,
      remote_url: url,
      content_type: attachment_data['mediaType'],
      media_type: media_type,
      file_name: file_name,
      file_size: 1,
      description: attachment_data['name'],
      width: attachment_data['width'],
      height: attachment_data['height'],
      blurhash: attachment_data['blurhash']
    }

    MediaAttachment.create!(media_attrs)
    Rails.logger.info "📎 Created remote media attachment: #{url}"
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn "⚠️ Failed to create media attachment: #{e.message}"
  end

  # Delete Activity処理
  def handle_delete_activity
    Rails.logger.info '🗑️ Processing Delete activity'

    object_id = extract_delete_object_id
    object = ActivityPubObject.find_by(ap_id: object_id)

    if authorized_to_delete?(object)
      object.destroy!
      Rails.logger.info "🗑️ Object deleted: #{object_id}"
    else
      Rails.logger.warn "⚠️ Object not found or unauthorized: #{object_id}"
    end

    head :accepted
  end

  def extract_delete_object_id
    object_id = @activity['object']
    object_id.is_a?(Hash) ? object_id['id'] : object_id
  end

  def authorized_to_delete?(object)
    object&.actor == @sender
  end

  # 可視性判定
end
