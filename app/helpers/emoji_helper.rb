# frozen_string_literal: true

module EmojiHelper
  def emojify(text, custom_emojis: nil, animate: true)
    return text if text.blank?

    custom_emojis ||= CustomEmoji.from_text(text)
    EmojiFormatter.emojify(text, custom_emojis: custom_emojis, animate: animate)
  end

  def custom_emoji_tag(emoji, css_class: 'emojione custom-emoji')
    return '' unless emoji

    image_tag emoji.url,
              alt: ":#{emoji.shortcode}:",
              title: ":#{emoji.shortcode}:",
              class: css_class,
              rel: 'emoji',
              draggable: 'false'
  end

  def emoji_react_component_props(custom_emojis)
    custom_emojis.map do |emoji|
      {
        shortcode: emoji.shortcode,
        static_url: emoji.static_url,
        url: emoji.url,
        visible_in_picker: true
      }
    end
  end
end
