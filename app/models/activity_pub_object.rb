# frozen_string_literal: true

class ActivityPubObject < ApplicationRecord
  self.table_name = 'objects'

  # === 定数 ===
  OBJECT_TYPES = %w[Note Article Image Video Audio Document Page].freeze
  VISIBILITY_LEVELS = %w[public unlisted followers_only direct].freeze

  # === バリデーション ===
  validates :ap_id, presence: true, uniqueness: true
  validates :object_type, presence: true, inclusion: { in: OBJECT_TYPES }
  validates :visibility, inclusion: { in: VISIBILITY_LEVELS }
  validates :published_at, presence: true
  validates :content, presence: true, if: :requires_content?
  validates :content, length: { maximum: 10_000 }

  # === アソシエーション ===
  belongs_to :actor, inverse_of: :objects
  has_many :activities, dependent: :destroy, inverse_of: :object
  has_many :favourites, dependent: :destroy, foreign_key: :object_id, inverse_of: :object
  has_many :reblogs, dependent: :destroy, foreign_key: :object_id, inverse_of: :object
  has_many :media_attachments, dependent: :destroy, inverse_of: :object, foreign_key: :object_id, primary_key: :id
  has_many :object_tags, dependent: :destroy, foreign_key: :object_id, inverse_of: :object
  has_many :tags, through: :object_tags
  has_many :mentions, dependent: :destroy, foreign_key: :object_id, inverse_of: :object
  has_many :mentioned_actors, through: :mentions, source: :actor

  # Conversations (for direct messages)
  belongs_to :conversation, optional: true

  # === スコープ ===
  scope :local, -> { where(local: true) }
  scope :remote, -> { where(local: false) }
  scope :public_posts, -> { where(visibility: 'public') }
  scope :unlisted, -> { where(visibility: 'unlisted') }
  scope :recent, -> { order(published_at: :desc) }
  scope :by_type, ->(type) { where(object_type: type) }
  scope :notes, -> { by_type('Note') }
  scope :articles, -> { by_type('Article') }
  scope :with_media, -> { joins(:media_attachments) }
  scope :without_replies, -> { where(in_reply_to_ap_id: nil) }

  # 会話関係
  scope :in_conversation, ->(conversation_id) { where(conversation_ap_id: conversation_id) }

  # === コールバック ===
  before_validation :set_defaults, on: :create
  before_validation :generate_snowflake_id, on: :create
  before_save :extract_plaintext
  before_save :set_conversation_id
  after_create :create_activity, if: :local?
  after_create :process_text_content, if: -> { local? && content.present? }
  after_create :update_actor_posts_count, if: -> { local? && object_type == 'Note' }
  after_update :process_text_content, if: -> { local? && saved_change_to_content? }
  after_destroy :create_delete_activity, if: :local?
  after_destroy :update_actor_posts_count, if: -> { local? && object_type == 'Note' }

  # === URL生成メソッド ===
  def public_url
    # Snowflake IDを使用してHTML URL生成
    scheme = Rails.env.production? ? 'https' : 'http'
    domain = Rails.application.config.activitypub.domain
    "#{scheme}://#{domain}/@#{actor.username}/#{id}"
  end

  def activitypub_url
    ap_id
  end

  # === ActivityPub関連メソッド ===

  def local?
    local
  end

  def remote?
    !local
  end

  def public?
    visibility == 'public'
  end

  def unlisted?
    visibility == 'unlisted'
  end

  def followers_only?
    visibility == 'followers_only'
  end

  def direct?
    visibility == 'direct'
  end

  def sensitive?
    sensitive
  end

  # === コンテンツ関連メソッド ===

  def note?
    object_type == 'Note'
  end

  def article?
    object_type == 'Article'
  end

  def media?
    media_attachments.any?
  end

  def reply?
    in_reply_to_ap_id.present?
  end

  def root_conversation
    return self unless reply?

    current = self
    current = current.in_reply_to while current.in_reply_to.present?
    current
  end

  def conversation_thread
    return ActivityPubObject.where(id: id) if conversation_ap_id.blank?

    ActivityPubObject.in_conversation(conversation_ap_id).recent
  end

  # === ActivityPub JSON-LD出力 ===

  def to_activitypub
    base_activitypub_data.merge(
      extended_activitypub_data
    ).compact
  end

  def base_activitypub_data
    {
      '@context' => Rails.application.config.activitypub.context_url,
      'id' => ap_id,
      'type' => object_type,
      'attributedTo' => actor.ap_id,
      'content' => content,
      'published' => published_at.iso8601,
      'url' => public_url
    }
  end

  def extended_activitypub_data
    {
      'inReplyTo' => in_reply_to_ap_id,
      'to' => build_audience_list(:to),
      'cc' => build_audience_list(:cc),
      'attachment' => build_attachment_list,
      'tag' => build_tag_list,
      'summary' => summary,
      'sensitive' => sensitive?,
      'source' => source_data,
      'replies' => replies_collection_data
    }
  end

  def source_data
    {
      'content' => content_plaintext,
      'mediaType' => 'text/plain'
    }
  end

  def replies_collection_data
    {
      'type' => 'Collection',
      'totalItems' => replies_count || 0
    }
  end

  # === 表示用メソッド ===

  def display_content
    return content_plaintext if content.blank?
    return content unless sensitive?

    summary.presence || 'Sensitive content'
  end

  def truncated_content(length = 500)
    return '' if content_plaintext.blank?

    if content_plaintext.length > length
      "#{content_plaintext[0, length]}..."
    else
      content_plaintext
    end
  end

  def formatted_content
    return '' if content.blank?

    # HTMLサニタイズ済みコンテンツとして扱う
    ActionController::Base.helpers.sanitize(content, tags: %w[p br strong em a],
                                                     attributes: %w[href])
  end

  private

  # === ActivityPub ヘルパーメソッド ===

  def build_audience_list(type)
    case visibility
    when 'public'
      build_public_audience_list(type)
    when 'unlisted'
      build_unlisted_audience_list(type)
    when 'followers_only'
      build_followers_audience_list(type)
    when 'direct'
      build_direct_audience_list(type)
    else
      []
    end
  end

  def build_public_audience_list(type)
    case type
    when :to
      [Rails.application.config.activitypub.public_collection_url]
    when :cc
      [actor.followers_url]
    end
  end

  def build_unlisted_audience_list(type)
    case type
    when :to
      [actor.followers_url]
    when :cc
      [Rails.application.config.activitypub.public_collection_url]
    end
  end

  def build_followers_audience_list(type)
    case type
    when :to
      [actor.followers_url]
    when :cc
      []
    end
  end

  def build_direct_audience_list(type)
    case type
    when :to
      # DMの場合はメンションされたアクターのAP IDを返す
      mentioned_actors.map(&:ap_id)
    when :cc
      []
    end
  end

  def build_attachment_list
    media_attachments.map do |attachment|
      {
        'type' => 'Document',
        'mediaType' => attachment.mime_type,
        'url' => attachment.file_url,
        'name' => attachment.description || attachment.filename,
        'width' => attachment.width,
        'height' => attachment.height,
        'blurhash' => attachment.blurhash
      }.compact
    end
  end

  def build_tag_list
    # ハッシュタグを追加
    tag_list = tags.map do |tag|
      {
        'type' => 'Hashtag',
        'name' => "##{tag.name}",
        'href' => "#{Rails.application.config.activitypub.base_url}/tags/#{tag.name}"
      }
    end

    # メンションされたアクターをMentionタグとして追加
    mentions.includes(:actor).find_each do |mention|
      tag_list << {
        'type' => 'Mention',
        'name' => "@#{mention.actor.username}@#{mention.actor.domain}",
        'href' => mention.actor.ap_id
      }
    end

    tag_list
  end

  # === バリデーション・コールバックヘルパー ===

  def set_defaults
    set_timestamps
    set_local_flag
    set_visibility_and_language
    set_sensitivity
    set_ap_id_for_local
  end

  def set_timestamps
    self.published_at ||= Time.current
  end

  def set_local_flag
    self.local = actor&.local? if local.nil?
  end

  def set_visibility_and_language
    self.visibility ||= 'public'
    self.language ||= 'ja'
  end

  def set_sensitivity
    self.sensitive = false if sensitive.nil?
  end

  def set_ap_id_for_local
    return unless local? && ap_id.blank?

    # Snowflake IDが生成されていない場合は生成
    generate_snowflake_id if id.blank?

    self.ap_id = generate_ap_id
  end

  def generate_snowflake_id
    return if id.present?

    self.id = Letter::Snowflake.generate
  end

  def generate_ap_id
    return unless local?

    "#{base_url}/users/#{actor.username}/posts/#{id}"
  end

  def base_url
    scheme = Rails.env.production? ? 'https' : 'http'
    domain = Rails.application.config.activitypub.domain
    "#{scheme}://#{domain}"
  end

  def extract_plaintext
    return if content.blank?

    # HTMLタグを除去してプレーンテキストを抽出
    self.content_plaintext = ActionController::Base.helpers.strip_tags(content)
                                                   .gsub(/\s+/, ' ')
                                                   .strip
  end

  def set_conversation_id
    if reply? && conversation_ap_id.blank?
      set_reply_conversation_id
    elsif conversation_ap_id.blank?
      set_new_conversation_id
    end
  end

  def set_reply_conversation_id
    parent = ActivityPubObject.find_by(ap_id: in_reply_to_ap_id)
    self.conversation_ap_id = parent&.conversation_ap_id || in_reply_to_ap_id
  end

  def set_new_conversation_id
    self.conversation_ap_id = ap_id
  end

  def requires_content?
    %w[Note Article].include?(object_type)
  end

  def create_activity
    Activity.create!(
      ap_id: "#{ap_id}#create",
      activity_type: 'Create',
      actor: actor,
      object_ap_id: ap_id,
      published_at: published_at,
      local: true
    )
  end

  def create_delete_activity
    Activity.create!(
      ap_id: "#{ap_id}#delete-#{Time.current.to_i}",
      activity_type: 'Delete',
      actor: actor,
      target_ap_id: ap_id,
      published_at: Time.current,
      local: true
    )
  end

  def process_text_content
    return if content.blank?

    parser = TextParser.new(content)
    parser.process_for_object(self)
  end

  def update_actor_posts_count
    actor.update_posts_count! if actor.present?
  rescue StandardError => e
    Rails.logger.error "Failed to update actor posts count: #{e.message}"
  end
end
