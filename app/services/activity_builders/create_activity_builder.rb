# frozen_string_literal: true

module ActivityBuilders
  class CreateActivityBuilder
    def initialize(activity)
      @activity = activity
    end

    def build
      return build_generic_activity_data unless @activity.object

      base_data = build_create_base_data
      base_data.merge('object' => build_create_object_data(@activity.object))
    end

    private

    attr_reader :activity

    def build_create_base_data
      base_fields.merge(audience_fields)
    end

    def build_create_object_data(object)
      # オブジェクト自体のActivityPub表現を使用（Poll対応含む）
      object.to_activitypub
    end

    def base_fields
      {
        '@context' => Rails.application.config.activitypub.context_url,
        'id' => activity.ap_id,
        'type' => 'Create',
        'actor' => activity.actor.ap_id,
        'published' => activity.published_at.iso8601
      }
    end

    def audience_fields
      audience_builder = AudienceBuilder.new(activity.object)
      {
        'to' => audience_builder.build(:to),
        'cc' => audience_builder.build(:cc)
      }
    end

    def build_generic_activity_data
      {
        '@context' => Rails.application.config.activitypub.context_url,
        'id' => activity.ap_id,
        'type' => activity.activity_type,
        'actor' => activity.actor.ap_id,
        'published' => activity.published_at.iso8601
      }
    end
  end
end
