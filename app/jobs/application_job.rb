# frozen_string_literal: true

class ApplicationJob < ActiveJob::Base
  # デッドロックが発生したジョブを自動的に再試行
  # retry_on ActiveRecord::Deadlocked

  # 基盤となるレコードが利用できない場合、ほとんどのジョブは無視しても安全
  # discard_on ActiveJob::DeserializationError

  private

  def handle_error(error, context_message = nil)
    message = context_message || "#{self.class.name} error"
    Rails.logger.error "💥 #{message}: #{error.message}"
    Rails.logger.error error.backtrace.first(3).join("\n")

    raise error unless executions < 3

    retry_job(wait: 1.minute)
  end
end
