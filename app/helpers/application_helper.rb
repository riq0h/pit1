# frozen_string_literal: true

module ApplicationHelper
  include MentionProcessingHelper
  include StatusSerializer

  def background_color
    load_instance_config['background_color'] || '#fdfbfb'
  end

  private

  def load_instance_config
    config_file = Rails.root.join('config', 'instance_config.yml')
    if File.exist?(config_file)
      YAML.load_file(config_file) || {}
    else
      {}
    end
  rescue StandardError
    {}
  end
end
