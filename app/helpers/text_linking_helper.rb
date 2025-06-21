# frozen_string_literal: true

require 'English'
module TextLinkingHelper
  def auto_link_urls(text)
    return ''.html_safe if text.blank?

    if text.include?('<img') && text.include?('custom-emoji')
      linked_text = apply_url_links_to_html(text)
      mention_linked_text = apply_mention_links_to_html(linked_text)
    else
      escaped_text = escape_and_format_text(text)
      linked_text = apply_url_links(escaped_text)
      mention_linked_text = apply_mention_links(linked_text)
    end
    mention_linked_text.html_safe
  end

  private

  def escape_and_format_text(text)
    plain_text = ActionView::Base.full_sanitizer.sanitize(text).strip
    ERB::Util.html_escape(plain_text).gsub("\n", '<br>')
  end

  def apply_url_links(text)
    link_pattern = /(https?:\/\/[^\s]+)/
    link_template = '<a href="\1" target="_blank" rel="noopener noreferrer" ' \
                    'class="text-blue-600 hover:text-blue-800 underline">' \
                    '\1</a>'
    text.gsub(link_pattern, link_template)
  end

  def apply_mention_links(text)
    mention_pattern = /@([a-zA-Z0-9_.-]+)@([a-zA-Z0-9.-]+\.[a-zA-Z]{2,})/
    text.gsub(mention_pattern) do
      username = ::Regexp.last_match(1)
      domain = ::Regexp.last_match(2)
      mention_url = build_mention_url(username, domain)
      "<a href=\"#{mention_url}\" target=\"_blank\" rel=\"noopener noreferrer\" " \
        'class="text-purple-600 hover:text-purple-800 underline font-medium">' \
        "@#{username}@#{domain}</a>"
    end
  end

  def apply_url_links_to_html(html_text)
    # HTMLタグの外側にあるURLのみをリンク化する
    # 既存のaタグ、imgタグなどを壊さないように注意深く処理

    # まず、既存のHTMLタグ位置を記録
    tags = []
    html_text.scan(/<[^>]+>/) { |match| tags << { content: match, start: $LAST_MATCH_INFO.begin(0), end: $LAST_MATCH_INFO.end(0) } }

    # URLパターンを探してリンク化（ただし、既存のタグ内は除外）
    url_pattern = /(https?:\/\/[^\s<>]+)/
    result = html_text.dup
    offset = 0

    html_text.scan(url_pattern) do |url|
      url_start = $LAST_MATCH_INFO.begin(0)
      url_end = $LAST_MATCH_INFO.end(0)

      # このURLが既存のHTMLタグ内にないかチェック
      inside_tag = tags.any? do |tag|
        url_start >= tag[:start] && url_end <= tag[:end]
      end

      unless inside_tag
        # リンク化
        linked_url = "<a href=\"#{url[0]}\" target=\"_blank\" rel=\"noopener noreferrer\" " \
                     "class=\"text-blue-600 hover:text-blue-800 underline\">#{url[0]}</a>"

        # オフセットを考慮して置換
        actual_start = url_start + offset
        actual_end = url_end + offset
        result[actual_start...actual_end] = linked_url
        offset += linked_url.length - url[0].length
      end
    end

    result
  end

  def apply_mention_links_to_html(html_text)
    mention_pattern = /@([a-zA-Z0-9_.-]+)@([a-zA-Z0-9.-]+\.[a-zA-Z]{2,})/
    html_text.gsub(mention_pattern) do
      username = ::Regexp.last_match(1)
      domain = ::Regexp.last_match(2)
      mention_url = build_mention_url(username, domain)
      "<a href=\"#{mention_url}\" target=\"_blank\" rel=\"noopener noreferrer\" " \
        'class="text-purple-600 hover:text-purple-800 underline font-medium">' \
        "@#{username}@#{domain}</a>"
    end
  end

  def build_mention_url(username, domain)
    safe_username = username.gsub(/[^a-zA-Z0-9_.-]/, '')
    safe_domain = domain.gsub(/[^a-zA-Z0-9.-]/, '')

    return '#' if safe_username.empty? || safe_domain.empty?

    "https://#{ERB::Util.url_encode(safe_domain)}/users/#{ERB::Util.url_encode(safe_username)}"
  end
end
