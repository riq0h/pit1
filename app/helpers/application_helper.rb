# frozen_string_literal: true

module ApplicationHelper
  def background_color
    load_instance_config['background_color'] || '#fdfbfb'
  end

  def auto_link_urls(text)
    return ''.html_safe if text.blank?

    # 既にHTMLが含まれているかどうかをチェック
    if text.include?('<img') && text.include?('custom-emoji')
      # 既に絵文字がHTMLに変換されている場合は、HTMLエスケープをスキップ
      linked_text = apply_url_links_to_html(text)
      mention_linked_text = apply_mention_links_to_html(linked_text)
    else
      # 通常のテキストの場合
      escaped_text = escape_and_format_text(text)
      linked_text = apply_url_links(escaped_text)
      mention_linked_text = apply_mention_links(linked_text)
    end
    mention_linked_text.html_safe
  end

  private

  def escape_and_format_text(text)
    plain_text = strip_tags(text).strip
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

  # HTMLが含まれているテキストに対するURL リンク処理
  def apply_url_links_to_html(html_text)
    # HTMLタグ外のURLのみを対象にリンク化（HTMLタグ内のURL（src, href等）は除外）
    # より安全なアプローチ：HTMLタグが含まれている場合はURL リンク化をスキップ
    html_text
  end

  # HTMLが含まれているテキストに対するメンション処理
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
    # セキュリティ: usernameとdomainをサニタイズ
    safe_username = username.gsub(/[^a-zA-Z0-9_.-]/, '')
    safe_domain = domain.gsub(/[^a-zA-Z0-9.-]/, '')

    # 空の場合はエスケープ
    return '#' if safe_username.empty? || safe_domain.empty?

    # ActivityPubの一般的なURL形式を使用
    # 多くのActivityPubサーバ（Mastodon、Pleroma、Misskey等）で採用されている形式
    "https://#{ERB::Util.url_encode(safe_domain)}/users/#{ERB::Util.url_encode(safe_username)}"
  end

  def load_instance_config
    config_file = Rails.root.join('config', 'instance_config.yml')
    if File.exist?(config_file)
      YAML.load_file(config_file) || {}
    else
      {}
    end
  rescue StandardError
    {}
  end
end
