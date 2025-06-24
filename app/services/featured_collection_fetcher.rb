# frozen_string_literal: true

class FeaturedCollectionFetcher
  def initialize
    @resolver = Search::RemoteResolverService.new
  end

  def fetch_for_actor(actor)
    return [] if actor.featured_url.blank?

    # 既存のPinnedStatusがある場合は、それらのオブジェクトを返す
    existing_pinned_objects = actor.pinned_statuses
                                   .includes(object: %i[actor media_attachments mentions tags poll])
                                   .ordered
                                   .map(&:object)

    return existing_pinned_objects if existing_pinned_objects.any?

    Rails.logger.info "📌 Fetching featured collection for #{actor.username}@#{actor.domain}"

    # featured collectionを取得（共通クライアントを使用）
    collection_data = ActivityPubClient.fetch_object(actor.featured_url)
    return [] unless collection_data

    featured_items = extract_featured_items(collection_data)
    Rails.logger.info "📌 Featured items found: #{featured_items.size}"

    # 各アイテムを取得してActivityPubObjectとして保存
    pinned_objects = []
    featured_items.take(5).each do |item_uri| # 最大5個まで
      object = @resolver.resolve_remote_status(item_uri)
      next unless object

      pinned_objects << object
      create_pinned_status_record(actor, object)
    end

    Rails.logger.info "📌 Fetched #{pinned_objects.size} featured items for #{actor.username}@#{actor.domain}"
    pinned_objects
  rescue StandardError => e
    Rails.logger.error "❌ Failed to fetch featured collection: #{e.message}"
    []
  end

  private

  def extract_featured_items(collection_data)
    items = []

    # OrderedCollectionの場合
    if collection_data['orderedItems']
      items = collection_data['orderedItems']
    # Collectionの場合
    elsif collection_data['items']
      items = collection_data['items']
    # OrderedCollectionPageの場合
    elsif collection_data['type'] == 'OrderedCollectionPage' && collection_data['orderedItems']
      items = collection_data['orderedItems']
    end

    # itemsの内容を正規化：URIの文字列に変換
    items.filter_map do |item|
      case item
      when String
        item # すでにURIの文字列
      when Hash
        item['id'] || item['url'] # オブジェクトの場合はidまたはurlを抽出
      else
        nil
      end
    end
  end

  def create_pinned_status_record(actor, object)
    return if PinnedStatus.exists?(actor: actor, object: object)

    PinnedStatus.create!(
      actor: actor,
      object: object,
      position: actor.pinned_statuses.count
    )
  rescue StandardError => e
    Rails.logger.error "❌ Failed to create pinned status record: #{e.message}"
  end
end
