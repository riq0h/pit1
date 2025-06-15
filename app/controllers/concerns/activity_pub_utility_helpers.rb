# frozen_string_literal: true

module ActivityPubUtilityHelpers
  extend ActiveSupport::Concern

  private

  def find_target_object(object_ap_id)
    target_object = ActivityPubObject.find_by(ap_id: object_ap_id)

    Rails.logger.warn "⚠️ Target object not found for activity: #{object_ap_id}" unless target_object

    target_object
  end

  def strip_html_tags(html_content)
    return '' unless html_content

    # 簡易的なHTMLタグ除去
    html_content.gsub(/<[^>]*>/, '')
  end

  def parse_published_date(published_str)
    return Time.current unless published_str

    Time.zone.parse(published_str)
  rescue StandardError
    Time.current
  end
end
