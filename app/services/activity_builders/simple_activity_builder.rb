# frozen_string_literal: true

module ActivityBuilders
  class SimpleActivityBuilder
    def initialize(activity)
      @activity = activity
    end

    def build
      {
        '@context' => Rails.application.config.activitypub.context_url,
        'id' => @activity.ap_id,
        'type' => @activity.activity_type,
        'actor' => @activity.actor.ap_id,
        'published' => @activity.published_at.iso8601
      }.tap do |data|
        data['object'] = @activity.target_ap_id if @activity.target_ap_id
      end
    end
  end
end
