# frozen_string_literal: true

module UrlBuildable
  extend ActiveSupport::Concern

  private

  def build_url_from_request(request = nil)
    req = request || self.request
    scheme = req.ssl? ? 'https' : 'http'
    port = req.port
    host = req.host

    return "#{scheme}://#{host}" if default_port?(scheme, port)

    "#{scheme}://#{host}:#{port}"
  end

  def build_url_from_config
    Rails.application.config.activitypub.base_url
  end

  def default_port?(scheme, port)
    (scheme == 'https' && port == 443) || (scheme == 'http' && port == 80)
  end
end
