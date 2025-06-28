# frozen_string_literal: true

# ActiveRecordのクエリコメントでアプリケーション名を小文字に設定
Rails.application.config.active_record.query_log_tags_enabled = true
Rails.application.config.active_record.query_log_tags = [
  :application,
  :controller,
  :action,
  :job
]

# アプリケーション名を小文字の'letter'に設定
Rails.application.config.active_record.application_name = 'letter'