# frozen_string_literal: true

module ApplicationHelper
  include MentionProcessingHelper
  include StatusSerializer

  def background_color
    ENV['BACKGROUND_COLOR'] || '#fdfbfb'
  end
end
