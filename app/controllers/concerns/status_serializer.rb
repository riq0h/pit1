# frozen_string_literal: true

module StatusSerializer
  extend ActiveSupport::Concern
  include TextLinkingHelper

  private


  def parse_content_with_emojis(content)
    return content if content.blank?

    EmojiParser.new(content).parse
  end

  def parse_content_links_only(content)
    return content if content.blank?
    
    # URLリンク化のみ行い、絵文字はショートコードのまま
    # API: クライアント側でemojis配列を使って絵文字処理
    # フロントエンド: 後続でparse_content_with_emojisを呼び出し
    auto_link_urls(content)
  end

  def parse_content_for_frontend(content)
    return content if content.blank?
    
    # フロントエンド用：URLリンク化 + 絵文字HTML変換を一括処理
    content_with_links = auto_link_urls(content)
    EmojiParser.new(content_with_links).parse
  end

  def serialized_emojis(status)
    return [] if status.content.blank?

    emojis = EmojiParser.new(status.content).emojis_used
    emojis.map(&:to_activitypub)
  rescue => e
    Rails.logger.warn "Failed to serialize emojis for status #{status.id}: #{e.message}"
    []
  end
end
