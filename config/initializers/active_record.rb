# frozen_string_literal: true

# ActiveRecordのクエリログ設定
Rails.application.config.active_record.query_log_tags_enabled = true
Rails.application.config.active_record.query_log_tags = [
  :application,
  :controller,
  :action,
  :job
]