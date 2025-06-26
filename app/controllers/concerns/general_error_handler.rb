# frozen_string_literal: true

module GeneralErrorHandler
  extend ActiveSupport::Concern

  private

  def handle_general_error(error, context = nil)
    log_prefix = context || self.class.name.demodulize.downcase.gsub('controller', '')
    Rails.logger.error "💥 #{log_prefix.capitalize} processing error: #{error.message}"
    Rails.logger.error error.backtrace.first(5).join("\n")
    head :internal_server_error
  end
end
