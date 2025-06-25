# frozen_string_literal: true

class TextParser
  HASHTAG_REGEX = /#([a-zA-Z0-9_\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FAF]+)/
  MENTION_REGEX = /@([a-zA-Z0-9_.-]+)(?:@([a-zA-Z0-9.-]+\.[a-zA-Z]{2,}))?/

  attr_reader :text, :hashtags, :mentions, :custom_emojis

  def initialize(text)
    @text = text.to_s
    @hashtags = []
    @mentions = []
    @custom_emojis = {}
    parse
  end

  def extract_hashtags
    @hashtags = text.scan(HASHTAG_REGEX).flatten.map(&:downcase).uniq
  end

  def extract_mentions
    mention_data = text.scan(MENTION_REGEX).map do |username, domain|
      {
        username: username,
        domain: domain,
        acct: domain ? "#{username}@#{domain}" : username
      }
    end
    @mentions = mention_data.uniq { |m| m[:acct] }
  end

  def extract_custom_emojis
    @custom_emojis = CustomEmoji.from_text(text)
  end

  def process_for_object(object)
    create_hashtags_for_object(object)
    create_mentions_for_object(object)
  end

  def create_hashtags_for_object(object)
    hashtags.each do |hashtag_name|
      tag = Tag.find_or_create_by(name: hashtag_name)
      object.object_tags.find_or_create_by(tag: tag)
    end
  end

  private

  def parse
    extract_hashtags
    extract_mentions
    extract_custom_emojis
  end

  def create_mentions_for_object(object)
    mentions.each do |mention_data|
      actor = find_actor_by_mention(mention_data)
      next unless actor

      object.mentions.find_or_create_by(actor: actor)
    end
  end

  def find_actor_by_mention(mention_data)
    if mention_data[:domain]
      # リモートアクター
      Actor.find_by(username: mention_data[:username], domain: mention_data[:domain])
    else
      # ローカルアクター
      Actor.find_by(username: mention_data[:username], local: true)
    end
  end
end
