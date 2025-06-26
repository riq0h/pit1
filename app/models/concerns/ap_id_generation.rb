# frozen_string_literal: true

module ApIdGeneration
  extend ActiveSupport::Concern

  private

  def set_ap_id
    return if ap_id.present?

    snowflake_id = Letter::Snowflake.generate
    self.ap_id = "#{Rails.application.config.activitypub.base_url}/#{snowflake_id}"
  end
end
