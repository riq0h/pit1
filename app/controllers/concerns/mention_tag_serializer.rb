# frozen_string_literal: true

module MentionTagSerializer
  extend ActiveSupport::Concern

  private

  def serialized_mentions(status)
    return [] unless status.respond_to?(:mentions) && status.mentions
    
    status.mentions.includes(:actor).map { |mention| serialize_mention(mention) }
  rescue => e
    Rails.logger.warn "Failed to serialize mentions for status #{status.id}: #{e.message}"
    []
  end

  def serialize_mention(mention)
    {
      id: mention.actor.id.to_s,
      username: mention.actor.username,
      acct: mention.acct,
      url: mention_url(mention.actor)
    }
  end

  def mention_url(actor)
    if actor.local?
      "#{Rails.application.config.activitypub.scheme}://#{Rails.application.config.activitypub.domain}/@#{actor.username}"
    else
      actor.ap_id
    end
  end

  def serialized_tags(status)
    return [] unless status.respond_to?(:tags) && status.tags
    
    status.tags.map do |tag|
      {
        name: tag.name,
        url: "#{Rails.application.config.activitypub.scheme}://#{Rails.application.config.activitypub.domain}/tags/#{tag.name}"
      }
    end
  rescue => e
    Rails.logger.warn "Failed to serialize tags for status #{status.id}: #{e.message}"
    []
  end
end
