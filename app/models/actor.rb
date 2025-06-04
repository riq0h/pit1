# frozen_string_literal: true

class Actor < ApplicationRecord
  # === バリデーション ===
  validates :username, presence: true,
                       format: { with: /\A[a-zA-Z0-9_]+\z/ },
                       length: { minimum: 1, maximum: 30 }
  validates :ap_id, presence: true, uniqueness: true
  validates :inbox_url, presence: true
  validates :outbox_url, presence: true
  validates :public_key, presence: true

  # ドメイン関連バリデーション
  validates :domain, uniqueness: { scope: :username }
  validate :local_actor_limits

  # === アソシエーション ===
  has_many :activities, dependent: :destroy, inverse_of: :actor
  has_many :objects, dependent: :destroy, inverse_of: :actor
  has_many :media_attachments, dependent: :destroy, inverse_of: :actor

  # フォロー関係
  has_many :following_relationships, class_name: 'Follow', dependent: :destroy, inverse_of: :actor
  has_many :follower_relationships, class_name: 'Follow',
                                    foreign_key: 'target_actor_id', dependent: :destroy, inverse_of: :target_actor

  # through関係
  has_many :following_actors, through: :following_relationships, source: :target_actor
  has_many :follower_actors, through: :follower_relationships, source: :actor

  # === スコープ ===
  scope :local, -> { where(local: true) }
  scope :remote, -> { where(local: false) }
  scope :not_suspended, -> { where(suspended: false) }
  scope :active, -> { not_suspended }

  # === コールバック ===
  before_validation :set_ap_id, if: :local?
  before_validation :set_urls, if: :local?
  before_create :generate_keypair, if: :local?

  # === ActivityPub関連メソッド ===

  def local?
    local
  end

  def remote?
    !local
  end

  def acct
    if local?
      username
    else
      "#{username}@#{domain}"
    end
  end

  def webfinger_subject
    "acct:#{acct}"
  end

  def activitypub_url
    if local?
      Rails.application.routes.url_helpers.actor_url(username)
    else
      ap_id
    end
  end

  def inbox_url_for_delivery
    shared_inbox_url.presence || inbox_url
  end

  # === 統計更新メソッド ===

  def increment_posts_count!
    update!(posts_count: posts_count + 1)
  end

  def decrement_posts_count!
    return unless posts_count.positive?

    update!(posts_count: posts_count - 1)
  end

  def update_following_count!
    new_count = following_relationships.accepted.count
    update!(following_count: new_count)
  end

  def update_followers_count!
    new_count = follower_relationships.accepted.count
    update!(followers_count: new_count)
  end

  private

  def set_ap_id
    return unless local? && username.present?

    self.ap_id = build_actor_url
  end

  def set_urls
    return unless local? && username.present?

    base_url = build_base_url
    self.inbox_url = "#{base_url}/users/#{username}/inbox"
    self.outbox_url = "#{base_url}/users/#{username}/outbox"
    self.followers_url = "#{base_url}/users/#{username}/followers"
    self.following_url = "#{base_url}/users/#{username}/following"
  end

  def build_base_url
    protocol = Rails.application.config.force_ssl ? 'https' : 'http'
    host = Rails.application.config.default_host || 'localhost:3000'
    "#{protocol}://#{host}"
  end

  def build_actor_url
    Rails.application.routes.url_helpers.actor_url(username)
  rescue StandardError
    "#{build_base_url}/users/#{username}"
  end

  def generate_keypair
    keypair = OpenSSL::PKey::RSA.generate(2048)
    self.private_key = keypair.to_pem
    self.public_key = keypair.public_key.to_pem
  end

  def local_actor_limits
    return unless local? && new_record?

    return unless Actor.local.count >= 2

    errors.add(:base, 'This spaceship is a two-seater.')
  end
end
