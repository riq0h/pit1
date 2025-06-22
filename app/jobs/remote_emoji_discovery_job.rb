# frozen_string_literal: true

class RemoteEmojiDiscoveryJob < ApplicationJob
  queue_as :default

  def perform(domain = nil)
    service = RemoteEmojiDiscoveryService.new

    if domain.present?
      # 特定のドメインからの絵文字発見
      service.discover_from_domain(domain)
      Rails.logger.info "Remote emoji discovery completed for domain: #{domain}"
    else
      # 全ての接触済みドメインから絵文字発見
      discovered_emojis = service.discover_from_domains
      Rails.logger.info "Remote emoji discovery completed. Discovered #{discovered_emojis.count} new emojis"
    end
  rescue StandardError => e
    Rails.logger.error "Remote emoji discovery job failed: #{e.message}"
    raise e
  end
end
