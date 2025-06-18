# frozen_string_literal: true

module ActivityBuilders
  class TagBuilder
    def initialize(object)
      @object = object
    end

    def build
      hashtag_tags + mention_tags
    end

    private

    def hashtag_tags
      @object.tags.map do |tag|
        {
          'type' => 'Hashtag',
          'href' => "#{Rails.application.config.activitypub.base_url}/tags/#{tag.name}",
          'name' => "##{tag.name}"
        }
      end
    end

    def mention_tags
      @object.mentions.includes(:actor).map do |mention|
        {
          'type' => 'Mention',
          'href' => mention.actor.ap_id,
          'name' => "@#{mention.actor.username}@#{mention.actor.domain}"
        }
      end
    end
  end
end
