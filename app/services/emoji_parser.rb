# frozen_string_literal: true

class EmojiParser
  EMOJI_REGEX = /:([a-zA-Z0-9_]+):/

  def initialize(text)
    @text = text.to_s
    @local_emojis = {}
    @remote_emojis = {}
  end

  def parse
    @text.gsub(EMOJI_REGEX) do |match|
      shortcode = Regexp.last_match(1)
      emoji = find_emoji(shortcode)

      if emoji
        build_emoji_html(emoji)
      else
        match # 絵文字が見つからない場合は元のテキストを返す
      end
    end
  end

  def extract_emoji_shortcodes
    @text.scan(EMOJI_REGEX).flatten.uniq
  end

  def emojis_used
    shortcodes = extract_emoji_shortcodes
    return [] if shortcodes.empty?

    CustomEmoji.enabled.visible.where(shortcode: shortcodes, domain: nil)
  end

  private

  def find_emoji(shortcode)
    # ローカル絵文字を優先して検索
    @local_emojis[shortcode] ||= CustomEmoji.enabled
                                            .visible
                                            .find_by(shortcode: shortcode, domain: nil)
  end

  def build_emoji_html(emoji)
    style = 'width: 1.2em; height: 1.2em; display: inline-block; ' \
            'vertical-align: text-bottom; object-fit: contain;'

    "<img src=\"#{emoji.image_url}\" alt=\":#{emoji.shortcode}:\" " \
      "title=\":#{emoji.shortcode}:\" class=\"custom-emoji\" " \
      "style=\"#{style}\" draggable=\"false\" />"
  end

  class << self
    def parse_text(text)
      new(text).parse
    end

    def extract_emojis(text)
      new(text).emojis_used
    end
  end
end
