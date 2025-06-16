# frozen_string_literal: true

class ConfigController < ApplicationController
  before_action :authenticate_user!

  # GET /config
  def show
    @config = current_instance_config
  end

  # PATCH /config
  def update
    if update_instance_config && update_user_profile
      redirect_to config_path, notice: I18n.t('config.updated')
    else
      @config = current_instance_config
      flash.now[:alert] = I18n.t('config.update_failed')
      render :show, status: :unprocessable_entity
    end
  end

  # GET /config/custom_emojis
  def custom_emojis
    @custom_emojis = base_emoji_scope
    @custom_emojis = apply_emoji_filters(@custom_emojis)
  end

  # GET /config/custom_emojis/new
  def new_custom_emoji
    @custom_emoji = CustomEmoji.new
  end

  # POST /config/custom_emojis
  def create_custom_emoji
    @custom_emoji = CustomEmoji.new(custom_emoji_params)

    if @custom_emoji.save
      redirect_to config_custom_emojis_path, notice: t('custom_emojis.created')
    else
      render :new_custom_emoji, status: :unprocessable_entity
    end
  end

  # GET /config/custom_emojis/:id/edit
  def edit_custom_emoji
    @custom_emoji = CustomEmoji.find(params[:id])
  end

  # PATCH /config/custom_emojis/:id
  def update_custom_emoji
    @custom_emoji = CustomEmoji.find(params[:id])

    if @custom_emoji.update(custom_emoji_params)
      redirect_to config_custom_emojis_path, notice: t('custom_emojis.updated')
    else
      render :edit_custom_emoji, status: :unprocessable_entity
    end
  end

  # DELETE /config/custom_emojis/:id
  def destroy_custom_emoji
    @custom_emoji = CustomEmoji.find(params[:id])
    @custom_emoji.destroy
    redirect_to config_custom_emojis_path, notice: t('custom_emojis.deleted')
  end

  # PATCH /config/custom_emojis/:id/enable
  def enable_custom_emoji
    @custom_emoji = CustomEmoji.find(params[:id])
    @custom_emoji.update(disabled: false)
    redirect_to config_custom_emojis_path, notice: t('custom_emojis.enabled')
  end

  # PATCH /config/custom_emojis/:id/disable
  def disable_custom_emoji
    @custom_emoji = CustomEmoji.find(params[:id])
    @custom_emoji.update(disabled: true)
    redirect_to config_custom_emojis_path, notice: t('custom_emojis.disabled')
  end

  # POST /config/custom_emojis/bulk_action
  def bulk_action_custom_emojis
    message = process_bulk_emoji_action(params[:action_type], params[:emoji_ids])
    redirect_to config_custom_emojis_path, **message
  end

  private

  def base_emoji_scope
    CustomEmoji.local.includes(:image_attachment).alphabetical.limit(50)
  end

  def apply_emoji_filters(scope)
    scope = scope.where('shortcode LIKE ?', "%#{params[:q]}%") if params[:q].present?
    scope = scope.where(disabled: false) if params[:enabled] == 'true'
    scope = scope.where(disabled: true) if params[:enabled] == 'false'
    scope
  end

  def process_bulk_emoji_action(action_type, emoji_ids)
    case action_type
    when 'enable'
      CustomEmoji.where(id: emoji_ids).update_all(disabled: false)
      { notice: t('custom_emojis.bulk_enabled') }
    when 'disable'
      CustomEmoji.where(id: emoji_ids).update_all(disabled: true)
      { notice: t('custom_emojis.bulk_disabled') }
    when 'delete'
      emojis_to_delete = CustomEmoji.where(id: emoji_ids).includes(:image_attachment)
      emojis_to_delete.find_each do |emoji|
        emoji.image.purge if emoji.image.attached?
        emoji.delete
      end
      { notice: t('custom_emojis.bulk_deleted') }
    else
      { alert: t('custom_emojis.invalid_action') }
    end
  end

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
      blog_footer: config_value(stored_config, 'blog_footer'),
      background_color: config_value(stored_config, 'background_color')
    }
  end

  def config_value(stored_config, key)
    if key == 'background_color'
      stored_config[key] || '#fdfbfb'
    else
      stored_config[key] || Rails.application.config.send(key.to_sym)
    end
  end

  def build_activitypub_config
    build_activitypub_settings.merge(build_r2_settings)
  end

  def build_activitypub_settings
    {
      activitypub_domain: Rails.application.config.activitypub.domain,
      character_limit: Rails.application.config.activitypub.character_limit,
      max_accounts: Rails.application.config.activitypub.max_accounts,
      federation_enabled: true # 常に有効化
    }
  end

  def build_r2_settings
    {
      s3_enabled: ENV['S3_ENABLED'] == 'true',
      s3_endpoint: ENV.fetch('S3_ENDPOINT', nil),
      s3_bucket: ENV.fetch('S3_BUCKET', nil),
      r2_access_key_id: ENV.fetch('R2_ACCESS_KEY_ID', nil),
      r2_secret_access_key: ENV.fetch('R2_SECRET_ACCESS_KEY', nil),
      s3_alias_host: ENV.fetch('S3_ALIAS_HOST', nil)
    }
  end

  def update_instance_config
    params = config_params
    return false if params.nil?

    save_config(params)
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

  def update_user_profile
    return true if params[:actor].blank?

    actor_params = params.expect(actor: %i[summary avatar])
    current_user.update(actor_params)
  rescue StandardError => e
    Rails.logger.error "User profile update failed: #{e.message}"
    false
  end

  def config_params
    permitted_params = params.expect(config: config_permitted_keys)

    # 背景色のバリデーション
    if permitted_params[:background_color].present? && !permitted_params[:background_color].match?(/\A#[0-9a-fA-F]{6}\z/)
      flash.now[:alert] = I18n.t('config.invalid_background_color')
      return nil
    end

    # R2設定を環境変数に反映
    update_env_vars(permitted_params) if permitted_params.present?

    permitted_params
  end

  def config_permitted_keys
    %i[instance_name instance_description instance_contact_email instance_maintainer blog_footer
       background_color s3_enabled s3_endpoint s3_bucket r2_access_key_id r2_secret_access_key
       s3_alias_host]
  end

  def update_env_vars(params)
    env_updates = build_env_updates(params)
    update_env_file(env_updates) if env_updates.present?
  end

  def build_env_updates(params)
    env_updates = {}
    env_updates['S3_ENABLED'] = params[:s3_enabled] == '1' ? 'true' : 'false'
    add_optional_env_updates(env_updates, params)
    env_updates
  end

  def add_optional_env_updates(env_updates, params)
    optional_keys = {
      s3_endpoint: 'S3_ENDPOINT',
      s3_bucket: 'S3_BUCKET',
      r2_access_key_id: 'R2_ACCESS_KEY_ID',
      r2_secret_access_key: 'R2_SECRET_ACCESS_KEY',
      s3_alias_host: 'S3_ALIAS_HOST'
    }

    optional_keys.each do |param_key, env_key|
      env_updates[env_key] = params[param_key] if params[param_key].present?
    end
  end

  def update_env_file(updates)
    env_file_path = Rails.root.join('.env')
    return unless File.exist?(env_file_path)

    env_content = File.read(env_file_path)

    updates.each do |key, value|
      if env_content.match?(/^#{key}=/)
        env_content.gsub!(/^#{key}=.*$/, "#{key}=#{value}")
      else
        env_content += "\n#{key}=#{value}"
      end
    end

    File.write(env_file_path, env_content)
    Rails.logger.info "Updated .env file with R2 settings: #{updates.keys.join(', ')}"
  end

  def custom_emoji_params
    params.expect(custom_emoji: %i[shortcode image category_id])
  end
end
