# frozen_string_literal: true

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

  def apply_url_links_to_html(html_text)
    html_text
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
