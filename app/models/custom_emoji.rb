# frozen_string_literal: true

class CustomEmoji < ApplicationRecord
  # バリデーション
  validates :shortcode, presence: true, format: { with: /\A[a-zA-Z0-9_]+\z/ }
  validates :shortcode, uniqueness: { scope: :domain, case_sensitive: false }
  validates :image_url, presence: true, if: -> { remote? }

  # スコープ
  scope :local, -> { where(domain: nil) }
  scope :remote, -> { where.not(domain: nil) }
  scope :enabled, -> { where(disabled: false) }
  scope :alphabetical, -> { order(:shortcode) }
  scope :by_domain, ->(domain) { where(domain: domain) }

  # ファイルアップロード
  has_one_attached :image

  # バリデーション
  validate :shortcode_length
  validate :image_presence

  # コールバック
  before_validation :generate_id, on: :create
  before_validation :normalize_shortcode
  after_create :update_cache
  after_update :update_cache
  after_destroy :update_cache

  # メソッド
  def local?
    domain.nil?
  end

  def remote?
    !local?
  end

  def url
    return image_url if remote?
    return unless image.attached?

    # Active Storageファイルの公開URLを生成
    if Rails.env.development?
      Rails.application.routes.url_helpers.url_for(image, host: 'localhost:3000')
    else
      Rails.application.routes.url_helpers.url_for(image)
    end
  end

  def image_url
    url
  end

  def static_url
    # ローカル絵文字の場合は同じURL、リモートの場合は静的版のURLがあれば使用
    image_url
  end

  # Mastodon API準拠のJSON表現
  def to_activitypub
    {
      id: id,
      shortcode: shortcode,
      url: image_url,
      static_url: static_url,
      visible_in_picker: true,
      category: category_id
    }
  end

  # ActivityPub表現
  def to_ap
    {
      id: id,
      type: 'Emoji',
      name: ":#{shortcode}:",
      icon: {
        type: 'Image',
        url: image_url
      }
    }
  end

  private

  def generate_id
    self.id ||= SecureRandom.uuid
  end

  def normalize_shortcode
    self.shortcode = shortcode.to_s.downcase.strip
  end

  def shortcode_length
    return if shortcode.blank?

    errors.add(:shortcode, 'must be between 2 and 30 characters') unless shortcode.length.between?(2, 30)
  end

  def image_presence
    return if remote? && image_url.present?
    return if local? && image.attached?

    errors.add(:image, 'must be present')
  end

  def update_cache
    Rails.cache.delete('custom_emojis')
    Rails.cache.delete("custom_emojis:#{domain}")
  end

  class << self
    def cached
      Rails.cache.fetch('custom_emojis', expires_in: 1.hour) do
        enabled.includes(:image_attachment).to_a
      end
    end

    def search(query)
      return none if query.blank?

      where('shortcode LIKE ?', "%#{query}%")
        .enabled
        .alphabetical
        .limit(20)
    end

    def by_shortcodes(shortcodes)
      where(shortcode: shortcodes, domain: nil)
        .enabled
    end

    def from_text(text)
      return {} if text.blank?

      emoji_regex = /:([a-zA-Z0-9_]+):/
      shortcodes = text.scan(emoji_regex).flatten.uniq

      return {} if shortcodes.empty?

      emojis = by_shortcodes(shortcodes)
      emojis.index_by(&:shortcode)
    end
  end
end
