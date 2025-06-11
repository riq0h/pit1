# frozen_string_literal: true

class ConfigController < ApplicationController
  before_action :authenticate_user!

  # GET /config
  def show
    @config = current_instance_config
  end

  # PATCH /config
  def update
    if update_instance_config
      redirect_to config_path, notice: I18n.t('config.updated')
    else
      @config = current_instance_config
      flash.now[:alert] = I18n.t('config.update_failed')
      render :show, status: :unprocessable_entity
    end
  end

  private

  def current_instance_config
    build_base_config.merge(build_activitypub_config)
  end

  def build_base_config
    stored_config = load_stored_config
    build_instance_config_hash(stored_config)
  end

  def build_instance_config_hash(stored_config)
    {
      instance_name: config_value(stored_config, 'instance_name'),
      instance_description: config_value(stored_config, 'instance_description'),
      instance_contact_email: config_value(stored_config, 'instance_contact_email'),
      instance_maintainer: config_value(stored_config, 'instance_maintainer'),
      blog_footer: config_value(stored_config, 'blog_footer')
    }
  end

  def config_value(stored_config, key)
    stored_config[key] || Rails.application.config.send(key.to_sym)
  end

  def build_activitypub_config
    {
      activitypub_domain: Rails.application.config.activitypub.domain,
      character_limit: Rails.application.config.activitypub.character_limit,
      max_accounts: Rails.application.config.activitypub.max_accounts,
      federation_enabled: true # 常に有効化
    }
  end

  def update_instance_config
    save_config(config_params)
    true
  rescue StandardError => e
    Rails.logger.error "Config update failed: #{e.message}"
    false
  end

  def load_stored_config
    config_file = Rails.root.join('config', 'instance_config.yml')
    if File.exist?(config_file)
      YAML.load_file(config_file) || {}
    else
      {}
    end
  rescue StandardError => e
    Rails.logger.error "Failed to load config: #{e.message}"
    {}
  end

  def save_config(new_config)
    config_file = Rails.root.join('config', 'instance_config.yml')
    current_config = load_stored_config

    log_config_details(new_config, current_config, config_file)
    updated_config = merge_configs(current_config, new_config)
    write_config_file(config_file, updated_config)
  end

  def log_config_details(new_config, current_config, config_file)
    Rails.logger.info "New config: #{new_config.inspect}"
    Rails.logger.info "Current config: #{current_config.inspect}"
    Rails.logger.info "Writing to: #{config_file}"
  end

  def merge_configs(current_config, new_config)
    current_config.merge(new_config.to_h.stringify_keys)
  end

  def write_config_file(config_file, updated_config)
    Rails.logger.info "Updated config: #{updated_config.inspect}"
    File.write(config_file, updated_config.to_yaml)
    Rails.logger.info 'Config saved successfully'
  end

  def config_params
    params.expect(config: %i[instance_name instance_description instance_contact_email instance_maintainer blog_footer])
  end
end
