# frozen_string_literal: true

module SnowflakeIdGeneration
  extend ActiveSupport::Concern

  included do
    before_create :generate_snowflake_id
  end

  private

  def generate_snowflake_id
    return if id.present?

    self.id = Letter::Snowflake.generate
  end
end
