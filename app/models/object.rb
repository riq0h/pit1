# frozen_string_literal: true

class Object < ApplicationRecord
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
  has_many :media_attachments, dependent: :destroy, inverse_of: :object

  # 返信関係
  belongs_to :in_reply_to, class_name: 'Object', optional: true
  has_many :replies, class_name: 'Object', foreign_key: 'in_reply_to_id',
                     dependent: :destroy, inverse_of: :in_reply_to

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
  before_save :extract_plaintext
  before_save :set_conversation_id
  after_create :create_activity, if: :local?
  after_destroy :create_delete_activity, if: :local?

  # === URL生成メソッド ===
  def public_url
    # ap_id の末尾部分（nanoid）を使用してHTML URL生成
    id_part = ap_id.split('/').last
    "https://#{Rails.application.config.activitypub.domain}/@#{actor.username}/#{id_part}"
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
    return Object.where(id: id) if conversation_ap_id.blank?

    Object.in_conversation(conversation_ap_id).recent
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

    self.ap_id = generate_ap_id
  end

  def generate_ap_id
    timestamp = Time.current.to_i
    "#{Rails.application.config.base_url}/objects/#{timestamp}-#{SecureRandom.hex(8)}"
  rescue StandardError
    "https://localhost:3000/objects/#{SecureRandom.uuid}"
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
    parent = Object.find_by(ap_id: in_reply_to_ap_id)
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
      object: self,
      published_at: published_at,
      local: true,
      processed: true
    )
  end

  def create_delete_activity
    Activity.create!(
      ap_id: "#{ap_id}#delete-#{Time.current.to_i}",
      activity_type: 'Delete',
      actor: actor,
      target_ap_id: ap_id,
      published_at: Time.current,
      local: true,
      processed: true
    )
  end
end
