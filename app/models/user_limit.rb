# frozen_string_literal: true

class UserLimit < ApplicationRecord
  # === 定数 ===
  LIMIT_TYPES = %w[
    daily_posts weekly_posts monthly_posts
    storage_quota bandwidth_quota
    follows_per_day following_limit followers_limit
    media_uploads_per_day
  ].freeze

  DEFAULT_LIMITS = {
    'daily_posts' => 100,
    'weekly_posts' => 500,
    'monthly_posts' => 2000,
    'storage_quota' => 1.gigabyte,
    'bandwidth_quota' => 10.gigabytes,
    'follows_per_day' => 50,
    'following_limit' => 2000,
    'followers_limit' => 10_000,
    'media_uploads_per_day' => 20
  }.freeze

  # === バリデーション ===
  validates :limit_type, presence: true, inclusion: { in: LIMIT_TYPES }
  validates :limit_value, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :current_usage, numericality: { greater_than_or_equal_to: 0 }
  validates :actor_id, uniqueness: { scope: :limit_type }

  # === アソシエーション ===
  belongs_to :actor, inverse_of: :user_limits

  # === スコープ ===
  scope :by_type, ->(type) { where(limit_type: type) }
  scope :exceeded, -> { where('current_usage >= limit_value') }
  scope :near_limit, -> { where('current_usage >= limit_value * 0.8') }
  scope :active, -> { where(enabled: true) }
  scope :recent, -> { order(updated_at: :desc) }

  # 特定のタイプ用スコープ
  scope :post_limits, -> { where(limit_type: %w[daily_posts weekly_posts monthly_posts]) }
  scope :storage_limits, -> { where(limit_type: %w[storage_quota bandwidth_quota]) }
  scope :social_limits, -> { where(limit_type: %w[follows_per_day following_limit followers_limit]) }

  # === コールバック ===
  before_validation :set_defaults, on: :create
  before_save :validate_usage_against_limit

  # === 制限チェックメソッド ===

  def exceeded?
    enabled? && current_usage >= limit_value
  end

  def near_limit?(threshold = 0.8)
    enabled? && current_usage >= (limit_value * threshold)
  end

  def remaining
    return Float::INFINITY unless enabled?

    [limit_value - current_usage, 0].max
  end

  def usage_percentage
    return 0 unless enabled? && limit_value.positive?

    ((current_usage.to_f / limit_value) * 100).round(1)
  end

  def enabled?
    enabled
  end

  def disabled?
    !enabled
  end

  # === 使用量更新メソッド ===

  def increment_usage!(amount = 1)
    increment!(:current_usage, amount)

    # 制限超過時の処理
    handle_limit_exceeded if exceeded?
  end

  def decrement_usage!(amount = 1)
    new_usage = [current_usage - amount, 0].max
    update!(current_usage: new_usage)
  end

  def reset_usage!
    update!(current_usage: 0, last_reset_at: Time.current)
  end

  def can_use?(amount = 1)
    return true unless enabled?

    (current_usage + amount) <= limit_value
  end

  # === 制限管理メソッド ===

  def enable!
    update!(enabled: true)
  end

  def disable!
    update!(enabled: false)
  end

  def update_limit!(new_limit)
    update!(limit_value: new_limit)
  end

  def should_reset?
    return false if last_reset_at.blank?

    case limit_type
    when 'daily_posts', 'follows_per_day', 'media_uploads_per_day'
      last_reset_at < 1.day.ago
    when 'weekly_posts'
      last_reset_at < 1.week.ago
    when 'monthly_posts'
      last_reset_at < 1.month.ago
    else
      false
    end
  end

  # === クラスメソッド ===

  def self.check_limit(actor, limit_type, amount = 1)
    limit = find_or_create_limit(actor, limit_type)
    limit.can_use?(amount)
  end

  def self.use_limit(actor, limit_type, amount = 1)
    limit = find_or_create_limit(actor, limit_type)

    return false unless limit.can_use?(amount)

    limit.increment_usage!(amount)
    true
  end

  def self.find_or_create_limit(actor, limit_type)
    find_or_create_by(actor: actor, limit_type: limit_type) do |limit|
      limit.limit_value = DEFAULT_LIMITS[limit_type] || 100
      limit.current_usage = 0
      limit.enabled = true
    end
  end

  def self.reset_periodic_limits!
    # 日次制限をリセット
    daily_limits = where(limit_type: %w[daily_posts follows_per_day media_uploads_per_day])
    daily_limits.find_each do |limit|
      limit.reset_usage! if limit.should_reset?
    end

    # 週次制限をリセット
    weekly_limits = where(limit_type: 'weekly_posts')
    weekly_limits.find_each do |limit|
      limit.reset_usage! if limit.should_reset?
    end

    # 月次制限をリセット
    monthly_limits = where(limit_type: 'monthly_posts')
    monthly_limits.find_each do |limit|
      limit.reset_usage! if limit.should_reset?
    end
  end

  # === 表示用メソッド ===

  def human_limit_value
    case limit_type
    when 'storage_quota', 'bandwidth_quota'
      human_file_size(limit_value)
    else
      limit_value.to_s
    end
  end

  def human_current_usage
    case limit_type
    when 'storage_quota', 'bandwidth_quota'
      human_file_size(current_usage)
    else
      current_usage.to_s
    end
  end

  def status_color
    return 'gray' unless enabled?

    case usage_percentage
    when 0...50
      'green'
    when 50...80
      'yellow'
    when 80...100
      'orange'
    else
      'red'
    end
  end

  private

  def set_defaults
    self.limit_value ||= DEFAULT_LIMITS[limit_type] || 100
    self.current_usage ||= 0
    self.enabled = true if enabled.nil?
    self.last_reset_at ||= Time.current
  end

  def validate_usage_against_limit
    return unless enabled? && current_usage > limit_value

    # 使用量が制限を超える場合は制限値に合わせる
    self.current_usage = limit_value
  end

  def handle_limit_exceeded
    # 制限超過時のログ出力
    Rails.logger.warn "User limit exceeded: #{actor.username} - #{limit_type} (#{current_usage}/#{limit_value})"

    # 必要に応じて通知やアクションを追加
    notify_limit_exceeded if should_notify?
  end

  def should_notify?
    # 最後の通知から1時間以上経過している場合のみ通知
    last_notified_at.nil? || last_notified_at < 1.hour.ago
  end

  def notify_limit_exceeded
    update!(last_notified_at: Time.current)

    # 実際の通知実装はここに追加
    # NotificationService.limit_exceeded(actor, self)
  end

  def human_file_size(size)
    return '0 B' if size.zero?

    units = %w[B KB MB GB TB]
    size_f = size.to_f
    unit_index = 0

    while size_f >= 1024 && unit_index < units.length - 1
      size_f /= 1024
      unit_index += 1
    end

    "#{size_f.round(1)} #{units[unit_index]}"
  end
end
