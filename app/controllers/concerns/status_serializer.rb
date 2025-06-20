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
    
    # API用: 絵文字HTMLがあればショートコードに戻す
    # クライアント側でemojis配列を使って絵文字処理
    content.gsub(/<img[^>]*alt=":([^"]+):"[^>]*\/>/, ':\1:')
  end

  def parse_content_for_frontend(content)
    return content if content.blank?
    
    # フロントエンド用: 絵文字HTMLタグが既にある場合はそのまま、ない場合は変換
    # ローカル投稿: 既にHTML形式で保存済み → そのまま表示
    # 外部投稿: ショートコードの可能性 → 変換が必要
    if content.include?('<img') && content.include?('custom-emoji')
      # 既に絵文字がHTMLで変換済み
      content
    else
      # ショートコードがあれば変換
      EmojiParser.new(content).parse
    end
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
