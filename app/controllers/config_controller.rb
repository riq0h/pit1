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
    {
      instance_name: stored_config['instance_name'] || Rails.application.config.instance_name,
      instance_description: stored_config['instance_description'] || Rails.application.config.instance_description,
      instance_contact_email: stored_config['instance_contact_email'] || Rails.application.config.instance_contact_email,
      instance_maintainer: stored_config['instance_maintainer'] || Rails.application.config.instance_maintainer,
      blog_footer: stored_config['blog_footer'] || Rails.application.config.blog_footer
    }
  end

  def build_activitypub_config
    {
      activitypub_domain: Rails.application.config.activitypub.domain,
      character_limit: Rails.application.config.activitypub.character_limit,
      max_accounts: Rails.application.config.activitypub.max_accounts,
      federation_enabled: true  # 常に有効化
    }
  end

  def update_instance_config
    begin
      save_config(config_params)
      true
    rescue => e
      Rails.logger.error "Config update failed: #{e.message}"
      false
    end
  end

  def load_stored_config
    config_file = Rails.root.join('config', 'instance_config.yml')
    if File.exist?(config_file)
      YAML.load_file(config_file) || {}
    else
      {}
    end
  rescue => e
    Rails.logger.error "Failed to load config: #{e.message}"
    {}
  end

  def save_config(new_config)
    config_file = Rails.root.join('config', 'instance_config.yml')
    current_config = load_stored_config
    
    Rails.logger.info "New config: #{new_config.inspect}"
    Rails.logger.info "Current config: #{current_config.inspect}"
    
    # 新しい設定をマージ
    updated_config = current_config.merge(new_config.to_h.stringify_keys)
    
    Rails.logger.info "Updated config: #{updated_config.inspect}"
    Rails.logger.info "Writing to: #{config_file}"
    
    # ファイルに保存
    File.write(config_file, updated_config.to_yaml)
    
    Rails.logger.info "Config saved successfully"
  end

  def config_params
    params.require(:config).permit(
      :instance_name,
      :instance_description,
      :instance_contact_email,
      :instance_maintainer,
      :blog_footer
    )
  end
end
