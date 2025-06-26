# frozen_string_literal: true

module ActivityPubObjectBuilding
  extend ActiveSupport::Concern

  private

  def build_activity_audience(object, type)
    ActivityBuilders::AudienceBuilder.new(object).build(type)
  end

  def build_object_attachments(object)
    ActivityBuilders::AttachmentBuilder.new(object).build
  end

  def build_object_tags(object)
    ActivityBuilders::TagBuilder.new(object).build
  end
end
