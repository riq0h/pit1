# frozen_string_literal: true

class OutboxManager
  attr_reader :actor

  def initialize(actor)
    @actor = actor
  end

  # 新規Activityを作成して配信
  def create_and_deliver_activity(activity_type:, object: nil, target_ap_id: nil, **options)
    Rails.logger.info "📤 Creating #{activity_type} activity for #{actor.username}"

    activity = build_activity(activity_type, object, target_ap_id, options)

    # Activityを保存
    activity.save!

    # フォロワーに配信
    deliver_to_followers(activity) if should_deliver_to_followers?(activity_type)

    # 特定のターゲットに配信
    deliver_to_target(activity, target_ap_id) if target_ap_id.present?

    Rails.logger.info "✅ Activity #{activity.id} created and queued for delivery"
    activity
  end

  # Create Activity（投稿作成）
  def create_note(content:, visibility: 'public', **options)
    object = create_note_object(content, visibility, options)

    create_and_deliver_activity(
      activity_type: 'Create',
      object: object,
      visibility: visibility
    )
  end

  # Follow Activity（フォロー送信）
  def follow_actor(target_actor)
    create_and_deliver_activity(
      activity_type: 'Follow',
      target_ap_id: target_actor.ap_id
    )
  end

  # Announce Activity（ブースト）
  def announce_object(target_object)
    create_and_deliver_activity(
      activity_type: 'Announce',
      target_ap_id: target_object.ap_id
    )
  end

  # Like Activity（いいね）
  def like_object(target_object)
    create_and_deliver_activity(
      activity_type: 'Like',
      target_ap_id: target_object.ap_id
    )
  end

  # Undo Activity（取り消し）
  def undo_activity(original_activity)
    create_and_deliver_activity(
      activity_type: 'Undo',
      target_ap_id: original_activity.ap_id
    )
  end

  # Delete Activity（削除）
  def delete_object(object)
    create_and_deliver_activity(
      activity_type: 'Delete',
      target_ap_id: object.ap_id
    )
  end

  private

  def build_activity(activity_type, object, target_ap_id, options)
    Activity.new(
      ap_id: generate_activity_id(activity_type),
      activity_type: activity_type,
      actor: actor,
      object: object,
      target_ap_id: target_ap_id,
      published_at: Time.current,
      local: true,
      processed: true,
      **options
    )
  end

  def generate_activity_id(activity_type)
    timestamp = Time.current.to_i
    random_id = SecureRandom.hex(16)
    "#{actor.ap_id}##{activity_type.downcase}-#{timestamp}-#{random_id}"
  end

  def create_note_object(content, visibility, options)
    ActivityPubObject.create!(
      ap_id: generate_object_id,
      object_type: 'Note',
      actor: actor,
      content: content,
      visibility: visibility,
      published_at: Time.current,
      local: true,
      sensitive: options[:sensitive] || false,
      summary: options[:summary],
      in_reply_to_ap_id: options[:in_reply_to_ap_id],
      conversation_ap_id: options[:conversation_ap_id]
    )
  end

  def generate_object_id
    # ActivityPubObjectと同じSnowflake ID生成方式を使用
    object_id = Letter::Snowflake.generate
    "#{actor.ap_id}/posts/#{object_id}"
  end

  def should_deliver_to_followers?(activity_type)
    %w[Create Announce].include?(activity_type)
  end

  def deliver_to_followers(activity)
    inbox_urls = collect_follower_inboxes

    return if inbox_urls.empty?

    Rails.logger.info "📬 Queuing delivery to #{inbox_urls.count} follower inboxes"
    SendActivityJob.perform_later(activity.id, inbox_urls)
  end

  def deliver_to_target(activity, target_ap_id)
    target_actor = find_target_actor(target_ap_id)

    return unless target_actor&.inbox_url

    Rails.logger.info "📬 Queuing delivery to target: #{target_actor.inbox_url}"
    SendActivityJob.perform_later(activity.id, [target_actor.inbox_url])
  end

  def collect_follower_inboxes
    # アクターのフォロワーのInbox URLを収集
    followers = actor.followers.where(local: false)

    inbox_urls = followers.filter_map(&:inbox_url).uniq

    # shared_inbox_urlがある場合は優先使用
    shared_inboxes = followers.filter_map(&:shared_inbox_url).uniq

    # 重複を除去してshared_inboxを優先
    shared_inboxes + (inbox_urls - extract_domains_from_shared_inboxes(shared_inboxes, inbox_urls))
  end

  def extract_domains_from_shared_inboxes(shared_inboxes, inbox_urls)
    shared_domains = shared_inboxes.filter_map { |url| URI(url).host }

    inbox_urls.reject do |inbox_url|
      shared_domains.include?(URI(inbox_url).host)
    end
  end

  def find_target_actor(target_ap_id)
    # ローカルアクターから検索
    Actor.find_by(ap_id: target_ap_id) ||
      # リモートアクターを取得
      ActorFetcher.new.fetch_and_create(target_ap_id)
  rescue StandardError => e
    Rails.logger.error "❌ Failed to find target actor #{target_ap_id}: #{e.message}"
    nil
  end
end
