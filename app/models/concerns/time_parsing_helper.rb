# frozen_string_literal: true

module TimeParsingHelper
  extend ActiveSupport::Concern

  # 統一された時刻パース処理
  def parse_timestamp(timestamp, default_on_error: :current, default_on_blank: :nil)
    return handle_default(default_on_blank) if timestamp.blank?

    Time.zone.parse(timestamp)
  rescue ArgumentError, StandardError
    handle_default(default_on_error)
  end

  # ISO8601フォーマット出力（safe navigation対応）
  def format_iso8601(time)
    time&.iso8601
  end

  # published_at優先のタイムスタンプ取得
  def primary_timestamp(object)
    object.published_at&.iso8601 || object.created_at.iso8601
  end

  private

  def handle_default(default_type)
    case default_type
    when :current then Time.current
    when :nil then nil
    else default_type
    end
  end
end
