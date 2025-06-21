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
    emoji_ids = params[:emoji_ids]&.reject(&:blank?)
    action_type = params[:action_type]

    if emoji_ids.blank?
      redirect_to config_custom_emojis_path, alert: t('custom_emojis.no_selection')
      return
    end

    result = process_bulk_emoji_action(action_type, emoji_ids)
    redirect_to config_custom_emojis_path, result
  end

  private

  def update_instance_config
    params = config_params
    return false if params.nil?

    save_config(params)
    true
  rescue StandardError => e
    Rails.logger.error "Config update failed: #{e.message}"
    false
  end

  def update_user_profile
    return true if params[:actor].blank?

    actor_params = params.require(:actor).permit(:note, :avatar, fields: [:name, :value])

    # fieldsをJSON形式で保存
    if actor_params[:fields].present?
      clean_fields = actor_params[:fields].reject { |field| field[:name].blank? && field[:value].blank? }
      actor_params[:fields] = clean_fields.to_json
    end

    current_user.update(actor_params)
  rescue StandardError => e
    Rails.logger.error "User profile update failed: #{e.message}"
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

    updated_config = merge_configs(current_config, new_config)
    write_config_file(config_file, updated_config)
  end

  def merge_configs(current_config, new_config)
    current_config.merge(new_config.compact)
  end

  def write_config_file(config_file, updated_config)
    File.open(config_file, 'w') do |file|
      file.write(updated_config.to_yaml)
    end
  end

  def config_params
    return nil unless params[:config]

    params.require(:config).permit(
      :instance_name,
      :instance_description,
      :instance_contact_email,
      :instance_maintainer,
      :blog_footer,
      :background_color
    )
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
      background_color: config_value(stored_config, 'background_color'),
      user_bio: current_user&.note || ''
    }
  end

  def config_value(stored_config, key)
    if key == 'background_color'
      stored_config[key] || '#fdfbfb'
    elsif key == 'instance_name'
      stored_config[key] || 'letter'
    elsif key == 'instance_description'
      stored_config[key] || 'General Letter Publication System based on ActivityPub'
    elsif key == 'instance_contact_email'
      stored_config[key] || 'admin@localhost'
    elsif key == 'instance_maintainer'
      stored_config[key] || 'letter Administrator'
    elsif key == 'blog_footer'
      stored_config[key] || 'General Letter Publication System based on ActivityPub'
    else
      stored_config[key]
    end
  end

  def build_activitypub_config
    build_activitypub_settings.merge(build_r2_settings)
  end

  def build_activitypub_settings
    {
      activitypub_domain: Rails.application.config.activitypub.domain,
      activitypub_base_url: Rails.application.config.activitypub.base_url
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

  def base_emoji_scope
    CustomEmoji.includes(:image_attachment).order(created_at: :desc)
  end

  def apply_emoji_filters(scope)
    scope = filter_by_category(scope)
    scope = filter_by_search(scope)
    paginate_emojis(scope)
  end

  def filter_by_category(scope)
    return scope unless params[:enabled].present?

    case params[:enabled]
    when 'true'
      scope.where(disabled: false)
    when 'false'
      scope.where(disabled: true)
    else
      scope
    end
  end

  def filter_by_search(scope)
    return scope unless params[:q].present?

    search_term = "%#{params[:q].upcase}%"
    scope.where('UPPER(shortcode) LIKE ? OR UPPER(domain) LIKE ?', search_term, search_term)
  end

  def paginate_emojis(scope)
    scope.limit(20)
  end

  def custom_emoji_params
    params.require(:custom_emoji).permit(:shortcode, :domain, :image, :disabled, :visible_in_picker)
  end
end