# frozen_string_literal: true

class Actor < ApplicationRecord
  # パスワード認証機能
  has_secure_password validations: false

  # アソシエーション
  has_many :objects, dependent: :destroy, class_name: 'ActivityPubObject'
  has_many :activities, dependent: :destroy
  has_many :media_attachments, dependent: :destroy
  has_many :favourites, dependent: :destroy
  has_many :reblogs, dependent: :destroy
  has_many :mentions, dependent: :destroy

  # Follow relationships
  has_many :following_relationships, class_name: 'Follow', dependent: :destroy, inverse_of: :actor
  has_many :following, through: :following_relationships, source: :target_actor
  has_many :follower_relationships, class_name: 'Follow', foreign_key: :target_actor_id, dependent: :destroy, inverse_of: :target_actor
  has_many :followers, through: :follower_relationships, source: :actor

  # Block/Mute relationships
  has_many :blocks, dependent: :destroy
  has_many :blocked_actors, through: :blocks, source: :target_actor
  has_many :blocked_by, class_name: 'Block', foreign_key: :target_actor_id, dependent: :destroy, inverse_of: :target_actor
  has_many :blocking_actors, through: :blocked_by, source: :actor

  has_many :mutes, dependent: :destroy
  has_many :muted_actors, through: :mutes, source: :target_actor
  has_many :muted_by, class_name: 'Mute', foreign_key: :target_actor_id, dependent: :destroy, inverse_of: :target_actor
  has_many :muting_actors, through: :muted_by, source: :actor

  # Domain blocking
  has_many :domain_blocks, dependent: :destroy

  # OAuth 2.0 associations (Doorkeeper)
  has_many :access_grants,
           class_name: 'Doorkeeper::AccessGrant',
           foreign_key: :resource_owner_id,
           dependent: :delete_all,
           inverse_of: :resource_owner

  has_many :access_tokens,
           class_name: 'Doorkeeper::AccessToken',
           foreign_key: :resource_owner_id,
           dependent: :delete_all,
           inverse_of: :resource_owner

  # フォロー関係
  has_many :follows, dependent: :destroy
  has_many :followed_actors, through: :follows, source: :target_actor
  has_many :reverse_follows, class_name: 'Follow', foreign_key: 'target_actor_id', dependent: :destroy, inverse_of: :target_actor

  # バリデーション
  validates :username, presence: true, format: { with: /\A[a-zA-Z0-9_]+\z/ }
  validates :ap_id, presence: true, uniqueness: true
  validates :inbox_url, presence: true
  validates :outbox_url, presence: true
  validates :public_key, presence: true
  validates :password, length: { minimum: 6 }, if: -> { local? && password.present? }

  # ローカルアクター制限（SQLiteトリガーで制御）
  validate :local_actor_limit, if: -> { local? && !Rails.env.test? }

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
    local_domain = Rails.application.config.activitypub.domain
    "acct:#{username}@#{domain || local_domain}"
  end

  # Public HTML URL
  def public_url
    return nil unless local?

    base_url = Rails.application.config.activitypub.base_url
    "#{base_url}/@#{username}"
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
      '@context' => Rails.application.config.activitypub.context_url,
      'type' => 'Follow',
      'id' => "#{ap_id}#follows/#{SecureRandom.uuid}",
      'actor' => ap_id,
      'object' => target_actor.ap_id
    }
  end

  def generate_accept_activity(follow)
    {
      '@context' => Rails.application.config.activitypub.context_url,
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
  def to_activitypub(request = nil)
    base_activitypub_data(request).merge(activitypub_links(request)).merge(activitypub_images(request)).compact
  end

  # フォロー・フォロワー数の更新
  def update_following_count!
    count = following_relationships.accepted.count
    update_column(:following_count, count)
  end

  def update_followers_count!
    count = follower_relationships.accepted.count
    update_column(:followers_count, count)
  end

  # 投稿数の更新
  def update_posts_count!
    count = objects.where(object_type: 'Note', local: true).count
    update_column(:posts_count, count)
  end

  # Block/Mute helper methods
  def blocking?(actor)
    return false unless actor

    blocks.exists?(target_actor: actor)
  end

  def blocked_by?(actor)
    return false unless actor

    blocked_by.exists?(actor: actor)
  end

  def muting?(actor)
    return false unless actor

    mutes.exists?(target_actor: actor)
  end

  def muted_by?(actor)
    return false unless actor

    muted_by.exists?(actor: actor)
  end

  def domain_blocking?(domain)
    return false unless domain

    domain_blocks.exists?(domain: domain)
  end

  def domain_blocked_by?(actor_domain)
    return false unless actor_domain && domain.present?

    # Check if any actor from actor_domain has blocked this actor's domain
    DomainBlock.joins(:actor)
               .exists?(actors: { domain: actor_domain }, domain_blocks: { domain: domain })
  end

  private

  # ActivityPub base data
  def base_activitypub_data(request = nil)
    base_url = get_base_url(request)
    actor_url = "#{base_url}/users/#{username}"

    {
      '@context' => [
        Rails.application.config.activitypub.context_url,
        'https://w3id.org/security/v1'
      ],
      'type' => actor_type || 'Person',
      'id' => actor_url,
      'preferredUsername' => username,
      'name' => display_name,
      'summary' => summary,
      'url' => actor_url,
      'discoverable' => discoverable,
      'manuallyApprovesFollowers' => manually_approves_followers
    }
  end

  # ActivityPub URLs
  def activitypub_links(request = nil)
    base_url = get_base_url(request)
    actor_url = "#{base_url}/users/#{username}"

    {
      'inbox' => "#{actor_url}/inbox",
      'outbox' => "#{actor_url}/outbox",
      'followers' => "#{actor_url}/followers",
      'following' => "#{actor_url}/following",
      'featured' => "#{actor_url}/collections/featured",
      'publicKey' => {
        'id' => "#{actor_url}#main-key",
        'owner' => actor_url,
        'publicKeyPem' => public_key
      }
    }
  end

  # ActivityPub images
  def activitypub_images(_request = nil)
    {
      'icon' => icon_url ? { 'type' => 'Image', 'url' => icon_url } : nil,
      'image' => header_url ? { 'type' => 'Image', 'url' => header_url } : nil
    }
  end

  # Get base URL from request or fallback to config
  def get_base_url(_request = nil)
    # 常に設定からのドメインを使用（.envで設定されたACTIVITYPUB_DOMAINを優先）
    build_url_from_config
  end

  def build_url_from_request(request)
    scheme = request.ssl? ? 'https' : 'http'
    port = request.port
    host = request.host

    return "#{scheme}://#{host}" if default_port?(scheme, port)

    "#{scheme}://#{host}:#{port}"
  end

  def build_url_from_config
    # .envで設定された値を使用
    Rails.application.config.activitypub.base_url
  end

  def default_port?(scheme, port)
    (scheme == 'https' && port == 443) || (scheme == 'http' && port == 80)
  end

  # RSA鍵ペア生成
  def generate_key_pair
    return unless local? && private_key.blank?

    rsa_key = OpenSSL::PKey::RSA.new(2048)

    self.private_key = rsa_key.to_pem
    self.public_key = rsa_key.public_key.to_pem
  end

  # ActivityPub URL設定
  def set_ap_urls
    return unless local?

    base_url = Rails.application.config.activitypub.base_url

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
