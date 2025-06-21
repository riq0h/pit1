# frozen_string_literal: true

class ConfigController < ApplicationController
  before_action :authenticate_user!

  # GET /config
  def show
    @config = current_instance_config
  end

  # PATCH /config
  def update
    if update_user_profile
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
    @custom_emoji.image.purge if @custom_emoji.image.attached?
    @custom_emoji.destroy
    redirect_to config_custom_emojis_path, notice: t('custom_emojis.deleted')
  end

  # PATCH /config/custom_emojis/:id/enable
  def enable_custom_emoji
    @custom_emoji = CustomEmoji.find(params[:id])
    @custom_emoji.update!(disabled: false)
    redirect_to config_custom_emojis_path, notice: t('custom_emojis.enabled')
  end

  # PATCH /config/custom_emojis/:id/disable
  def disable_custom_emoji
    @custom_emoji = CustomEmoji.find(params[:id])
    @custom_emoji.update!(disabled: true)
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

  def update_user_profile
    return true unless params[:config]

    user_bio = params[:config][:user_bio]
    return true unless user_bio

    current_user.update(note: user_bio)
  rescue StandardError => e
    Rails.logger.error "User profile update failed: #{e.message}"
    false
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
    {
      instance_name: ENV['INSTANCE_NAME'] || 'letter',
      instance_description: ENV['INSTANCE_DESCRIPTION'] || 'General Letter Publication System based on ActivityPub',
      instance_contact_email: ENV['INSTANCE_CONTACT_EMAIL'] || 'admin@localhost',
      instance_maintainer: ENV['INSTANCE_MAINTAINER'] || 'letter Administrator',
      blog_footer: ENV['BLOG_FOOTER'] || 'General Letter Publication System based on ActivityPub',
      background_color: ENV['BACKGROUND_COLOR'] || '#fdfbfb',
      user_bio: current_user&.note || ENV['USER_BIO'] || '',
      s3_enabled: ENV['S3_ENABLED'] == 'true',
      s3_endpoint: ENV['S3_ENDPOINT'],
      s3_bucket: ENV['S3_BUCKET'],
      r2_access_key_id: ENV['R2_ACCESS_KEY_ID'],
      r2_secret_access_key: ENV['R2_SECRET_ACCESS_KEY'],
      s3_alias_host: ENV['S3_ALIAS_HOST']
    }
  end

  def build_activitypub_config
    {
      activitypub_domain: Rails.application.config.activitypub.domain,
      activitypub_base_url: Rails.application.config.activitypub.base_url
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
    return scope unless params[:category].present?

    case params[:category]
    when 'enabled'
      scope.where(disabled: false)
    when 'disabled'
      scope.where(disabled: true)
    else
      scope
    end
  end

  def filter_by_search(scope)
    return scope unless params[:search].present?

    search_term = "%#{params[:search]}%"
    scope.where('shortcode ILIKE ? OR domain ILIKE ?', search_term, search_term)
  end

  def paginate_emojis(scope)
    scope.page(params[:page]).per(20)
  end

  def custom_emoji_params
    params.require(:custom_emoji).permit(:shortcode, :domain, :image, :disabled, :visible_in_picker)
  end
end
