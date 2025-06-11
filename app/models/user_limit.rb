# frozen_string_literal: true

class UserLimit < ApplicationRecord
  belongs_to :actor, optional: true

  # === バリデーション ===
  validates :limit_type, presence: true,
                         inclusion: { in: %w[max_accounts] }
  validates :limit_value, presence: true, numericality: { greater_than: 0 }
  validates :current_usage, presence: true, numericality: { greater_than_or_equal_to: 0 }

  # システム制限（actor_id = nil）の場合のバリデーション
  validates :actor_id, absence: true, if: -> { limit_type == 'max_accounts' }

  # === スコープ ===
  scope :system_limits, -> { where(actor_id: nil) }
  scope :enabled, -> { where(enabled: true) }

  # === 制限タイプ ===
  LIMIT_TYPES = {
    'max_accounts' => {
      name: 'Maximum Accounts',
      description: 'Maximum number of local accounts (letter = 2)',
      default_value: 2,
      scope: :system
    }
  }.freeze

  # === クラスメソッド ===

  # アカウント作成時の制限チェック
  def self.can_create_account?
    max_accounts_limit = system_limits.find_by(limit_type: 'max_accounts')
    return true unless max_accounts_limit&.enabled?

    current_accounts = Actor.local.active.count
    current_accounts < max_accounts_limit.limit_value
  end

  # アカウント作成後の使用量更新
  def self.increment_account_usage!
    max_accounts_limit = find_or_create_system_limit('max_accounts')
    max_accounts_limit.increment!(:current_usage)
  end

  # アカウント削除後の使用量更新
  def self.decrement_account_usage!
    max_accounts_limit = find_or_create_system_limit('max_accounts')
    max_accounts_limit.decrement!(:current_usage) if max_accounts_limit.current_usage.positive?
  end

  # 投稿時の文字数チェック（データベースを使わず設定値から）
  def self.valid_post_length?(content)
    return true if content.blank?

    # プレーンテキストの文字数をカウント
    plaintext = ActionController::Base.helpers.strip_tags(content)
    character_limit = Rails.application.config.activitypub.character_limit

    plaintext.length <= character_limit
  end

  # 現在の文字数制限を取得（設定ファイルから）
  def self.character_limit
    Rails.application.config.activitypub.character_limit
  end

  # システム制限の取得または作成
  def self.find_or_create_system_limit(limit_type)
    system_limits.find_or_create_by(limit_type: limit_type) do |limit|
      config = LIMIT_TYPES[limit_type]
      limit.limit_value = config[:default_value]
      limit.current_usage = calculate_current_usage(limit_type)
      limit.enabled = true
    end
  end

  # 現在の使用量を計算
  def self.calculate_current_usage(limit_type)
    case limit_type
    when 'max_accounts'
      Actor.local.active.count
    else
      0
    end
  end

  # === インスタンスメソッド ===

  def system_limit?
    actor_id.nil?
  end

  def limit_info
    LIMIT_TYPES[limit_type] || {}
  end

  def usage_percentage
    return 0 if limit_value.zero?

    (current_usage.to_f / limit_value * 100).round(1)
  end

  def near_limit?
    usage_percentage >= 80.0
  end

  def at_limit?
    current_usage >= limit_value
  end

  def display_usage
    case limit_type
    when 'max_accounts'
      "#{current_usage}/#{limit_value} accounts"
    else
      "#{current_usage}/#{limit_value}"
    end
  end

  def spaceship_status
    case limit_type
    when 'max_accounts'
      if at_limit?
        "🚀 This spaceship is full! (#{current_usage}/#{limit_value} seats taken)"
      elsif current_usage == 1
        "🚀 One pilot aboard, one seat remaining (#{current_usage}/#{limit_value})"
      else
        "🚀 Empty spaceship ready for crew (#{current_usage}/#{limit_value})"
      end
    else
      display_usage
    end
  end
end
