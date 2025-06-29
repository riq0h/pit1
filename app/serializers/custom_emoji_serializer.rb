# frozen_string_literal: true

class CustomEmojiSerializer < ActiveModel::Serializer
  attributes :shortcode, :url, :static_url, :visible_in_picker?, :category

  delegate :url, to: :object

  delegate :static_url, to: :object

  def visible_in_picker?
    true
  end

  def category
    object.category_id
  end
end
