# frozen_string_literal: true

module ActivityBuilders
  class AudienceBuilder
    def initialize(object)
      @object = object
    end

    def build(type)
      case @object.visibility
      when 'public'
        build_public_audience(type)
      when 'unlisted'
        build_unlisted_audience(type)
      when 'private'
        build_followers_audience(type)
      when 'direct'
        build_direct_audience(type)
      else
        []
      end
    end

    private

    def build_public_audience(type)
      case type
      when :to
        [Rails.application.config.activitypub.public_collection_url]
      when :cc
        [@object.actor.followers_url]
      end
    end

    def build_unlisted_audience(type)
      case type
      when :to
        [@object.actor.followers_url]
      when :cc
        [Rails.application.config.activitypub.public_collection_url]
      end
    end

    def build_followers_audience(type)
      case type
      when :to
        [@object.actor.followers_url]
      when :cc
        []
      end
    end

    def build_direct_audience(type)
      case type
      when :to
        @object.mentioned_actors&.pluck(:ap_id) || []
      when :cc
        []
      end
    end
  end
end
