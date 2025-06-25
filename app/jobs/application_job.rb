# frozen_string_literal: true

class ApplicationJob < ActiveJob::Base
  # デッドロックが発生したジョブを自動的に再試行
  # retry_on ActiveRecord::Deadlocked

  # 基盤となるレコードが利用できない場合、ほとんどのジョブは無視しても安全
  # discard_on ActiveJob::DeserializationError
end
