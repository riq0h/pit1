# frozen_string_literal: true

require_relative '../../services/html_stripper'

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

    # DMの場合、会話処理を実行
    handle_direct_message_conversation(object, object_data) if object.visibility == 'direct'

    # リプライの場合、親投稿のリプライ数を更新
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

  def update_reply_count_if_needed(object)
    return unless object.in_reply_to_ap_id

    parent_object = ActivityPubObject.find_by(ap_id: object.in_reply_to_ap_id)
    return unless parent_object

    parent_object.increment!(:replies_count)
    Rails.logger.info "💬 Reply count updated for #{parent_object.ap_id}: #{parent_object.replies_count}"
  end

  def handle_direct_message_conversation(object, object_data)
    Rails.logger.info "💬 Processing DM conversation for #{object.id}"

    # 受信者（ローカルユーザ）を特定
    to_addresses = object_data['to'] || []
    local_recipients = find_local_recipients_from_addresses(to_addresses)

    if local_recipients.empty?
      Rails.logger.warn '⚠️ No local recipients found for DM'
      return
    end

    # 送信者と受信者で会話を作成/取得
    participants = [object.actor] + local_recipients
    conversation = Conversation.find_or_create_for_actors(participants)

    # ステータスを会話に関連付け
    object.update!(conversation: conversation)
    conversation.update_last_status!(object)

    Rails.logger.info "💬 DM conversation updated: #{conversation.id}"
  end

  def find_local_recipients_from_addresses(to_addresses)
    local_actors = []

    to_addresses.each do |address|
      # ローカルユーザのActivityPub IDかチェック
      if address.start_with?(Rails.application.config.activitypub.base_url)
        actor = Actor.find_by(ap_id: address, local: true)
        local_actors << actor if actor
      end
    end

    local_actors
  end
end
