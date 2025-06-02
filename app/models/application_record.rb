# frozen_string_literal: true

class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  # SQLite JSON field support for ActivityPub data
  include ActiveSupport::Configurable

  class << self
    private

    def json_field(field_name)
      serialize field_name, coder: JSON

      define_method "#{field_name}=" do |value|
        super(value.is_a?(String) ? JSON.parse(value) : value)
      rescue JSON::ParserError
        super({})
      end

      define_method field_name do
        super() || {}
      end
    end

    def array_field(field_name, default: [])
      serialize field_name, coder: JSON

      define_method "#{field_name}=" do |value|
        super(value.is_a?(String) ? JSON.parse(value) : value)
      rescue JSON::ParserError
        super(default)
      end

      define_method field_name do
        super() || default
      end
    end
  end
end
