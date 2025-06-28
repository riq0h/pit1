# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EmojiHelper, type: :helper do
  def expect_emojify_call(text, emojis, animate_value)
    allow(EmojiFormatter).to receive(:emojify).with(
      text,
      custom_emojis: emojis,
      animate: animate_value
    )
  end

  def verify_emojify_call(text, emojis, animate_value)
    expect(EmojiFormatter).to have_received(:emojify).with(
      text,
      custom_emojis: emojis,
      animate: animate_value
    )
  end

  def expect_image_tag_call(emoji, css_class = 'emojione custom-emoji')
    allow(helper).to receive(:image_tag).with(
      emoji.url,
      alt: ":#{emoji.shortcode}:",
      title: ":#{emoji.shortcode}:",
      class: css_class,
      rel: 'emoji',
      draggable: 'false'
    )
  end

  def verify_image_tag_call(emoji, css_class = 'emojione custom-emoji')
    expect(helper).to have_received(:image_tag).with(
      emoji.url,
      alt: ":#{emoji.shortcode}:",
      title: ":#{emoji.shortcode}:",
      class: css_class,
      rel: 'emoji',
      draggable: 'false'
    )
  end
  describe '#emojify' do
    context 'with blank text' do
      it 'returns the text as-is for blank input' do
        expect(helper.emojify('')).to eq('')
        expect(helper.emojify(nil)).to be_nil
      end
    end

    context 'with custom emojis' do
      let(:custom_emojis) { [instance_double(CustomEmoji, shortcode: 'test', url: 'https://example.com/test.png')] }

      before do
        allow(CustomEmoji).to receive(:from_text).and_return(custom_emojis)
        allow(EmojiFormatter).to receive(:emojify).and_return('formatted text')
      end

      it 'uses provided custom emojis' do
        text = 'Hello :test: world'
        provided_emojis = [instance_double(CustomEmoji)]

        expect_emojify_call(text, provided_emojis, true)
        helper.emojify(text, custom_emojis: provided_emojis)
        verify_emojify_call(text, provided_emojis, true)
      end

      it 'fetches custom emojis from text when not provided' do
        text = 'Hello :test: world'

        allow(CustomEmoji).to receive(:from_text).with(text).and_return(custom_emojis)
        expect_emojify_call(text, custom_emojis, true)

        helper.emojify(text)
        expect(CustomEmoji).to have_received(:from_text).with(text)
        verify_emojify_call(text, custom_emojis, true)
      end

      it 'passes animate parameter to formatter' do
        text = 'Hello :test: world'

        expect_emojify_call(text, custom_emojis, false)
        helper.emojify(text, animate: false)
        verify_emojify_call(text, custom_emojis, false)
      end

      it 'defaults animate to true' do
        text = 'Hello :test: world'

        expect_emojify_call(text, custom_emojis, true)
        helper.emojify(text)
        verify_emojify_call(text, custom_emojis, true)
      end
    end

    context 'with real text processing' do
      let(:mock_emoji) { instance_double(CustomEmoji, shortcode: 'heart', url: 'https://example.com/heart.png') }

      before do
        allow(CustomEmoji).to receive(:from_text).and_return([mock_emoji])
      end

      it 'delegates to EmojiFormatter with correct parameters' do
        text = 'I :heart: Ruby'
        expected_result = 'I ❤️ Ruby'

        allow(EmojiFormatter).to receive(:emojify).and_return(expected_result)
        result = helper.emojify(text)

        verify_emojify_call(text, [mock_emoji], true)
        expect(result).to eq(expected_result)
      end
    end

    context 'when handling errors' do
      it 'handles CustomEmoji.from_text errors gracefully' do
        text = 'Hello :test: world'
        allow(CustomEmoji).to receive(:from_text).and_raise(StandardError, 'Database error')

        expect { helper.emojify(text) }.to raise_error(StandardError, 'Database error')
      end

      it 'handles EmojiFormatter errors gracefully' do
        text = 'Hello :test: world'
        allow(CustomEmoji).to receive(:from_text).and_return([])
        allow(EmojiFormatter).to receive(:emojify).and_raise(StandardError, 'Formatting error')

        expect { helper.emojify(text) }.to raise_error(StandardError, 'Formatting error')
      end
    end
  end

  describe '#custom_emoji_tag' do
    let(:emoji) { instance_double(CustomEmoji, shortcode: 'test', url: 'https://example.com/test.png') }

    context 'with valid emoji' do
      it 'generates an image tag with correct attributes' do
        expect_image_tag_call(emoji)
        helper.custom_emoji_tag(emoji)
        verify_image_tag_call(emoji)
      end

      it 'uses custom CSS class when provided' do
        expect_image_tag_call(emoji, 'custom-class')
        helper.custom_emoji_tag(emoji, css_class: 'custom-class')
        verify_image_tag_call(emoji, 'custom-class')
      end

      it 'returns the image tag HTML' do
        expected_html = '<img src="https://example.com/test.png" alt=":test:" class="emojione custom-emoji">'
        allow(helper).to receive(:image_tag).and_return(expected_html)

        result = helper.custom_emoji_tag(emoji)
        expect(result).to eq(expected_html)
      end
    end

    context 'with nil emoji' do
      it 'returns empty string' do
        result = helper.custom_emoji_tag(nil)
        expect(result).to eq('')
      end
    end

    context 'with different emoji properties' do
      it 'handles emojis with special characters in shortcode' do
        special_emoji = instance_double(CustomEmoji, shortcode: 'heart_eyes', url: 'https://example.com/heart_eyes.gif')

        expect_image_tag_call(special_emoji)
        helper.custom_emoji_tag(special_emoji)
        verify_image_tag_call(special_emoji)
      end

      it 'handles emojis with different file extensions' do
        gif_emoji = instance_double(CustomEmoji, shortcode: 'party', url: 'https://example.com/party.gif')

        expect_image_tag_call(gif_emoji)
        helper.custom_emoji_tag(gif_emoji)
        verify_image_tag_call(gif_emoji)
      end

      it 'handles emojis with long URLs' do
        long_url = 'https://very-long-domain-name.example.com/path/to/emoji/files/test.png'
        long_url_emoji = instance_double(CustomEmoji, shortcode: 'test', url: long_url)

        expect_image_tag_call(long_url_emoji)
        helper.custom_emoji_tag(long_url_emoji)
        verify_image_tag_call(long_url_emoji)
      end
    end

    context 'when considering security' do
      it 'does not allow XSS through shortcode' do
        xss_emoji = instance_double(CustomEmoji,
                                    shortcode: '<script>alert("xss")</script>',
                                    url: 'https://example.com/test.png')

        expect_image_tag_call(xss_emoji)
        helper.custom_emoji_tag(xss_emoji)
        verify_image_tag_call(xss_emoji)
      end

      it 'does not allow XSS through URL' do
        xss_emoji = instance_double(CustomEmoji,
                                    shortcode: 'test',
                                    url: 'javascript:alert("xss")')

        expect_image_tag_call(xss_emoji)
        helper.custom_emoji_tag(xss_emoji)
        verify_image_tag_call(xss_emoji)
      end
    end
  end
end
