# frozen_string_literal: true

module MentionProcessingHelper
  def prepend_mentions_to_content(post)
    return post.content if post.mentions.empty?

    external_mentions = find_external_mentions(post)
    return post.content if external_mentions.empty?

    new_mentions = find_new_mentions(external_mentions, post.content)
    return post.content if new_mentions.empty?

    prepend_mentions_to_html(post.content, new_mentions)
  end

  private

  def find_external_mentions(post)
    post.mentions.includes(:actor).reject { |mention| mention.actor.local? }
  end

  def find_new_mentions(external_mentions, content)
    mention_strings = build_mention_strings(external_mentions)
    content_text = strip_tags(content)
    existing_mentions = find_existing_mentions(mention_strings, content_text)

    mention_strings - existing_mentions
  end

  def build_mention_strings(external_mentions)
    external_mentions.map do |mention|
      actor = mention.actor
      "@#{actor.username}@#{actor.domain}"
    end
  end

  def find_existing_mentions(mention_strings, content_text)
    mention_strings.select { |mention| content_text.include?(mention) }
  end

  def prepend_mentions_to_html(content, new_mentions)
    mention_prefix = "#{new_mentions.join(' ')} "

    if content.start_with?('<p>')
      content.sub(/^<p>/, "<p>#{mention_prefix}")
    else
      "#{mention_prefix}#{content}"
    end
  end
end
