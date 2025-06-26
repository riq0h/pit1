# frozen_string_literal: true

class Activity < ApplicationRecord
  include SnowflakeIdGeneration
  include RemoteLocalHelper

  # === 定数 ===
  ACTIVITY_TYPES = %w[
    Create Update Delete Follow Accept Reject Block Undo
    Like Announce Add Remove Flag
  ].freeze

  # === バリデーション ===
  validates :ap_id, presence: true, uniqueness: true
  validates :activity_type, presence: true, inclusion: { in: ACTIVITY_TYPES }
  validates :published_at, presence: true

  # === アソシエーション ===
  belongs_to :actor, inverse_of: :activities
  belongs_to :object, optional: true, inverse_of: :activities, class_name: 'ActivityPubObject', foreign_key: :object_ap_id, primary_key: :ap_id

  # === スコープ ===
  scope :local, -> { where(local: true) }
  scope :remote, -> { where(local: false) }
  scope :processed, -> { where(processed: true) }
  scope :unprocessed, -> { where(processed: false) }
  scope :delivered, -> { where.not(delivered_at: nil) }
  scope :undelivered, -> { where(delivered_at: nil) }
  scope :recent, -> { order(published_at: :desc) }
  scope :by_type, ->(type) { where(activity_type: type) }

  # 特定のタイプ用スコープ
  scope :creates, -> { by_type('Create') }
  scope :follows, -> { by_type('Follow') }
  scope :likes, -> { by_type('Like') }
  scope :announces, -> { by_type('Announce') }

  # === コールバック ===
  before_validation :set_defaults, on: :create
  before_validation :generate_snowflake_id, on: :create
  after_create :process_activity!, if: :should_auto_process?

  # === ActivityPub関連メソッド ===

  def local?
    local
  end

  def target_object
    return object if object.present?
    return find_target_by_ap_id if target_ap_id.present?

    nil
  end

  def activitypub_url
    if local?
      Rails.application.routes.url_helpers.activity_url(id)
    else
      ap_id
    end
  end

  # === 処理メソッド ===

  def mark_as_processed!
    update!(processed: true, processed_at: Time.current)
  end

  def process_activity!
    return if processed?

    processor = ActivityProcessor.new(self)
    processor.process!

    mark_as_processed!
  rescue StandardError => e
    Rails.logger.error "Failed to process activity #{id}: #{e.message}"
    raise
  end

  def processed?
    processed
  end

  # === タイプ判定メソッド ===

  def create?
    activity_type == 'Create'
  end

  def follow?
    activity_type == 'Follow'
  end

  def accept?
    activity_type == 'Accept'
  end

  def like?
    activity_type == 'Like'
  end

  def announce?
    activity_type == 'Announce'
  end

  def delete?
    activity_type == 'Delete'
  end

  def undo?
    activity_type == 'Undo'
  end

  private

  def set_defaults
    self.published_at ||= Time.current
    self.local = actor&.local? if local.nil?
    self.processed = false if processed.nil?
  end

  def generate_snowflake_id
    return if id.present?

    self.id = Letter::Snowflake.generate.to_s
  end

  def should_auto_process?
    local? && %w[Create Accept].include?(activity_type)
  end

  def find_target_by_ap_id
    # オブジェクトを AP ID で検索
    ActivityPubObject.find_by(ap_id: target_ap_id) ||
      Actor.find_by(ap_id: target_ap_id) ||
      Activity.find_by(ap_id: target_ap_id)
  end
end
