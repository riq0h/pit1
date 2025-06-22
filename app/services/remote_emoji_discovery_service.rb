# frozen_string_literal: true

class RemoteEmojiDiscoveryService
  include HTTParty

  def initialize
    @discovered_emojis = []
  end

  # 接触したドメインからカスタム絵文字を発見・取得
  def discover_from_domains
    remote_domains = Actor.remote.distinct.pluck(:domain).compact

    remote_domains.each do |domain|
      discover_from_domain(domain)
    end

    @discovered_emojis
  end

  # 特定のドメインから絵文字を発見
  def discover_from_domain(domain)
    return if domain.blank?

    Rails.logger.info "🔍 Discovering emojis from domain: #{domain}"

    # まずはnodeinfo経由で絵文字エンドポイントを取得
    emoji_endpoint = find_emoji_endpoint(domain)

    if emoji_endpoint
      fetch_emojis_from_endpoint(domain, emoji_endpoint)
    else
      # フォールバック: 標準的なMastodon APIエンドポイントを試す
      fetch_emojis_from_api(domain)
    end
  rescue StandardError => e
    Rails.logger.warn "Failed to discover emojis from #{domain}: #{e.message}"
  end

  # ActivityPubオブジェクトから絵文字を抽出
  def extract_from_activitypub_object(ap_object, domain)
    return unless ap_object.is_a?(Hash) && ap_object['tag'].present?

    emoji_tags = ap_object['tag'].select { |tag| tag['type'] == 'Emoji' }

    emoji_tags.each do |emoji_tag|
      process_emoji_tag(emoji_tag, domain)
    end
  end

  private

  def find_emoji_endpoint(domain)
    # Well-knownのnodeinfoから絵文字エンドポイントを取得
    nodeinfo_url = "https://#{domain}/.well-known/nodeinfo"

    response = HTTParty.get(nodeinfo_url, timeout: 10)
    return nil unless response.success?

    nodeinfo_data = JSON.parse(response.body)
    links = nodeinfo_data['links'] || []

    # NodeInfo 2.0またはそれ以降を探す
    nodeinfo_link = links.find { |link| link['rel'] == 'http://nodeinfo.diaspora.software/ns/schema/2.0' }
    nodeinfo_link ||= links.find { |link| link['rel'] == 'http://nodeinfo.diaspora.software/ns/schema/2.1' }

    return nil unless nodeinfo_link

    nodeinfo_response = HTTParty.get(nodeinfo_link['href'], timeout: 10)
    return nil unless nodeinfo_response.success?

    nodeinfo = JSON.parse(nodeinfo_response.body)
    nodeinfo.dig('metadata', 'nodeName') ? "https://#{domain}/api/v1/custom_emojis" : nil
  rescue StandardError
    nil
  end

  def fetch_emojis_from_endpoint(domain, endpoint)
    Rails.logger.info "📡 Fetching emojis from endpoint: #{endpoint}"

    response = HTTParty.get(endpoint, timeout: 15)
    return unless response.success?

    emojis_data = JSON.parse(response.body)
    return unless emojis_data.is_a?(Array)

    emojis_data.each do |emoji_data|
      process_emoji_data(emoji_data, domain)
    end
  rescue StandardError => e
    Rails.logger.warn "Failed to fetch emojis from #{endpoint}: #{e.message}"
  end

  def fetch_emojis_from_api(domain)
    # Mastodon標準APIエンドポイントを試す
    api_url = "https://#{domain}/api/v1/custom_emojis"

    response = HTTParty.get(api_url, timeout: 15)
    return unless response.success?

    emojis_data = JSON.parse(response.body)
    return unless emojis_data.is_a?(Array)

    emojis_data.each do |emoji_data|
      process_emoji_data(emoji_data, domain)
    end
  rescue StandardError => e
    Rails.logger.warn "Failed to fetch emojis from API #{domain}: #{e.message}"
  end

  def process_emoji_data(emoji_data, domain)
    shortcode = emoji_data['shortcode'] || emoji_data['name']&.gsub(/^:|:$/, '')
    url = emoji_data['url'] || emoji_data['static_url']

    return if shortcode.blank? || url.blank?

    create_or_update_remote_emoji(shortcode, url, domain, emoji_data)
  end

  def process_emoji_tag(emoji_tag, domain)
    name = emoji_tag['name']&.gsub(/^:|:$/, '')
    url = emoji_tag.dig('icon', 'url')

    return if name.blank? || url.blank?

    create_or_update_remote_emoji(name, url, domain, emoji_tag)
  end

  def create_or_update_remote_emoji(shortcode, url, domain, metadata = {})
    # 既存のリモート絵文字を検索
    existing_emoji = CustomEmoji.find_by(shortcode: shortcode, domain: domain)

    if existing_emoji
      # URLが変更されている場合は更新
      if existing_emoji.image_url != url
        existing_emoji.update!(image_url: url, uri: metadata['id'])
        Rails.logger.debug { "Updated remote emoji: :#{shortcode}: from #{domain}" }
      end
    else
      # 新しいリモート絵文字を作成
      emoji = CustomEmoji.new(
        shortcode: shortcode,
        domain: domain,
        image_url: url,
        uri: metadata['id'] || "https://#{domain}/emojis/#{shortcode}",
        disabled: false,
        visible_in_picker: false # リモート絵文字はデフォルトで非表示
      )

      if emoji.save
        @discovered_emojis << emoji
        Rails.logger.info "Discovered new remote emoji: :#{shortcode}: from #{domain}"
      else
        Rails.logger.warn "Failed to save remote emoji :#{shortcode}: #{emoji.errors.full_messages.join(', ')}"
      end
    end
  rescue StandardError => e
    Rails.logger.error "Error processing emoji :#{shortcode}: from #{domain}: #{e.message}"
  end
end
