# frozen_string_literal: true

module ValidationErrorRendering
  extend ActiveSupport::Concern

  private

  def render_validation_error(object_or_message = nil)
    case object_or_message
    when String
      render json: { error: object_or_message }, status: :unprocessable_entity
    when nil
      render json: {
        error: 'Validation failed',
        details: current_user.errors.full_messages
      }, status: :unprocessable_entity
    else
      render json: {
        error: 'Validation failed',
        details: object_or_message.errors.full_messages
      }, status: :unprocessable_entity
    end
  end
end
