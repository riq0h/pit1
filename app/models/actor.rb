# frozen_string_literal: true

class Actor < ApplicationRecord
  # アソシエーション
  has_many :objects, dependent: :destroy, class_name: 'ActivityPubObject'
  has_many :activities, dependent: :destroy
  has_many :media_attachments, dependent: :destroy

  # フォロー関係
  has_many :follows, dependent: :destroy
  has_many :followed_actors, through: :follows, source: :target_actor
  has_many :reverse_follows, class_name: 'Follow', foreign_key: 'target_actor_id', dependent: :destroy, inverse_of: :target_actor
  has_many :followers, through: :reverse_follows, source: :actor

  # バリデーション
  validates :username, presence: true, format: { with: /\A[a-zA-Z0-9_]+\z/ }
  validates :ap_id, presence: true, uniqueness: true
  validates :inbox_url, presence: true
  validates :outbox_url, presence: true
  validates :public_key, presence: true

  # ローカルアクター制限（SQLiteトリガーで制御）
  validate :local_actor_limit, if: :local?

  # スコープ
  scope :local, -> { where(local: true) }
  scope :remote, -> { where(local: false) }
  scope :discoverable, -> { where(discoverable: true) }

  # コールバック
  before_create :generate_key_pair, if: :local?
  before_create :set_ap_urls, if: :local?

  # ActivityPub URLs
  def followers_url
    return super if super.present?

    "#{ap_id}/followers" if local?
  end

  def following_url
    return super if super.present?

    "#{ap_id}/following" if local?
  end

  def featured_url
    return super if super.present?

    "#{ap_id}/collections/featured" if local?
  end

  # WebFinger identifier
  def webfinger_subject
    default_domain = ENV['DOMAIN'] || 'localhost:3000'
    "acct:#{username}@#{domain || default_domain}"
  end

  # Display methods
  def display_name_or_username
    display_name.presence || username
  end

  def full_username
    local? ? username : "#{username}@#{domain}"
  end

  # Key management
  def public_key_object
    @public_key_object ||= OpenSSL::PKey::RSA.new(public_key) if public_key.present?
  end

  def private_key_object
    @private_key_object ||= OpenSSL::PKey::RSA.new(private_key) if private_key.present?
  end

  def public_key_id
    "#{ap_id}#main-key"
  end

  # Activity generation
  def generate_follow_activity(target_actor)
    {
      '@context' => 'https://www.w3.org/ns/activitystreams',
      'type' => 'Follow',
      'id' => "#{ap_id}#follows/#{SecureRandom.uuid}",
      'actor' => ap_id,
      'object' => target_actor.ap_id
    }
  end

  def generate_accept_activity(follow)
    {
      '@context' => 'https://www.w3.org/ns/activitystreams',
      'type' => 'Accept',
      'id' => "#{ap_id}#accepts/follows/#{follow.id}",
      'actor' => ap_id,
      'object' => {
        'type' => 'Follow',
        'id' => follow.follow_activity_ap_id,
        'actor' => follow.actor.ap_id,
        'object' => ap_id
      }
    }
  end

  # ActivityPub JSON-LD representation
  def to_activitypub
    base_activitypub_data.merge(activitypub_links).merge(activitypub_images).compact
  end

  private

  # ActivityPub base data
  def base_activitypub_data
    {
      '@context' => [
        'https://www.w3.org/ns/activitystreams',
        'https://w3id.org/security/v1'
      ],
      'type' => actor_type || 'Person',
      'id' => ap_id,
      'preferredUsername' => username,
      'name' => display_name,
      'summary' => summary,
      'url' => ap_id,
      'discoverable' => discoverable,
      'manuallyApprovesFollowers' => manually_approves_followers
    }
  end

  # ActivityPub URLs
  def activitypub_links
    {
      'inbox' => inbox_url,
      'outbox' => outbox_url,
      'followers' => followers_url,
      'following' => following_url,
      'featured' => featured_url,
      'publicKey' => {
        'id' => public_key_id,
        'owner' => ap_id,
        'publicKeyPem' => public_key
      }
    }
  end

  # ActivityPub images
  def activitypub_images
    {
      'icon' => icon_url ? { 'type' => 'Image', 'url' => icon_url } : nil,
      'image' => header_url ? { 'type' => 'Image', 'url' => header_url } : nil
    }
  end

  # RSA鍵ペア生成
  def generate_key_pair
    return unless local? && private_key.blank?

    Rails.logger.info "🔑 Generating RSA key pair for #{username}"

    rsa_key = OpenSSL::PKey::RSA.new(2048)

    self.private_key = rsa_key.to_pem
    self.public_key = rsa_key.public_key.to_pem
  end

  # ActivityPub URL設定
  def set_ap_urls
    return unless local?

    default_domain = ENV['DOMAIN'] || 'localhost:3000'
    scheme = ENV['FORCE_SSL'] == 'true' ? 'https' : 'http'
    base_url = "#{scheme}://#{default_domain}"

    self.ap_id ||= "#{base_url}/users/#{username}"
    self.inbox_url ||= "#{base_url}/users/#{username}/inbox"
    self.outbox_url ||= "#{base_url}/users/#{username}/outbox"
  end

  # ローカルアクター数制限（SQLiteトリガーと連携）
  def local_actor_limit
    return unless local?

    local_count = Actor.where(local: true).where.not(id: id).count

    return unless local_count >= 2

    errors.add(:local, 'This spaceship is a two-seater')
  end
end
