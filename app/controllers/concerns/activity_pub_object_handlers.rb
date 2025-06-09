# frozen_string_literal: true

module ActivityPubObjectHandlers
  extend ActiveSupport::Concern

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
      summary: object_data['summary'],
      icon_url: object_data.dig('icon', 'url'),
      header_url: object_data.dig('image', 'url'),
      raw_data: object_data
    )
    Rails.logger.info "👤 Actor updated: #{@sender.username}"
  end

  def update_object_content(object_data)
    object = Object.find_by(ap_id: object_data['id'])

    return unless object&.actor == @sender

    object.update!(build_update_attributes(object_data))
    Rails.logger.info "📝 Object updated: #{object.id}"
  end

  def build_update_attributes(object_data)
    {
      content: object_data['content'],
      content_plaintext: ActivityPub::HtmlStripper.strip(object_data['content']),
      summary: object_data['summary'],
      sensitive: object_data['sensitive'] || false,
      raw_data: object_data
    }
  end

  # Delete Activity処理
  def handle_delete_activity
    Rails.logger.info '🗑️ Processing Delete activity'

    object_id = extract_delete_object_id
    object = Object.find_by(ap_id: object_id)

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
  def determine_visibility(object_data)
    to = Array(object_data['to'])
    cc = Array(object_data['cc'])

    return 'public' if to.include?('https://www.w3.org/ns/activitystreams#Public')
    return 'unlisted' if cc.include?('https://www.w3.org/ns/activitystreams#Public')
    return 'private' if to.include?(@target_actor.followers_url)

    'direct'
  end
end
