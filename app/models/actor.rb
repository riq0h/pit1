# frozen_string_literal: true

class Actor < ApplicationRecord
  # バリデーション
  validates :username, presence: true,
                       format: { with: /\A[a-zA-Z0-9_]+\z/ },
                       length: { maximum: 30 }
  validates :ap_id, presence: true, uniqueness: true
  validates :inbox_url, :outbox_url, presence: true

  # スコープ
  scope :local, -> { where(local: true) }
  scope :remote, -> { where(local: false) }
  scope :active, -> { where(suspended: false) }

  # リレーション
  has_many :activities, dependent: :destroy, inverse_of: :actor
  has_many :objects, dependent: :destroy, inverse_of: :actor
  has_many :follows, dependent: :destroy, inverse_of: :actor
  has_many :follower_relationships, class_name: 'Follow',
                                    foreign_key: 'target_actor_id', dependent: :destroy, inverse_of: :target_actor
  has_many :followers, through: :follower_relationships, source: :actor
  has_many :following, through: :follows, source: :target_actor

  # ActivityPub支援メソッド
  def acct
    local? ? username : "#{username}@#{domain}"
  end

  def local?
    domain.nil?
  end

  def webfinger_subject
    "acct:#{acct}"
  end

  def generate_key_pair!
    key = OpenSSL::PKey::RSA.new(2048)
    self.public_key = key.public_key.to_pem
    self.private_key = key.to_pem if local?
    save!
  end
end
