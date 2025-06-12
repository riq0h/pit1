# frozen_string_literal: true

module ApplicationHelper
  def background_color
    load_instance_config['background_color'] || '#fdfbfb'
  end

  def auto_link_urls(text)
    return '' if text.blank?

    simple_format(h(text)).gsub(/(https?:\/\/[^\s]+)/,
                                '<a href="\1" target="_blank" rel="noopener noreferrer" class="text-blue-600 hover:text-blue-800 underline">\1</a>')
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
