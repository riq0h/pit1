# frozen_string_literal: true

class ConfigController < ApplicationController
  include BulkEmojiActions
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
    @tab = params[:tab] || 'local'
    @custom_emojis = base_emoji_scope_for_tab(@tab)
    @custom_emojis = apply_emoji_filters(@custom_emojis)

    # リモートドメインの統計情報
    return unless @tab == 'remote'

    @remote_domains = CustomEmoji.remote.group(:domain).count
  end

  # GET /config/relays
  def relays
    @relays = Relay.all
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
      redirect_to config_custom_emojis_path(tab: params[:tab]), alert: '絵文字を選択してください'
      return
    end

    result = process_bulk_emoji_action(action_type, emoji_ids, detailed_messages: true, detailed_copy_messages: true)
    redirect_to config_custom_emojis_path(tab: params[:tab]), result
  end

  # POST /config/custom_emojis/copy_remote
  def copy_remote_emojis
    emoji_ids = params[:emoji_ids]&.reject(&:blank?)

    if emoji_ids.blank?
      redirect_to config_custom_emojis_path(tab: 'remote'), alert: 'コピーする絵文字を選択してください'
      return
    end

    copy_service = RemoteEmojiCopyService.new
    results = copy_service.copy_multiple(emoji_ids)

    if results[:success_count].positive?
      message = "#{results[:success_count]}個の絵文字をローカルにコピーしました"
      message += "（#{results[:failed_count]}個は失敗）" if results[:failed_count].positive?
      redirect_to config_custom_emojis_path(tab: 'local'), notice: message
    else
      error_details = results[:failed_copies].map { |f| "#{f[:emoji].shortcode}: #{f[:error]}" }.join(', ')
      redirect_to config_custom_emojis_path(tab: 'remote'), alert: "すべての絵文字のコピーに失敗しました: #{error_details}"
    end
  end

  # POST /config/custom_emojis/discover_remote
  def discover_remote_emojis
    domain = params[:domain]&.strip

    if domain.present?
      # 特定ドメインからの発見
      RemoteEmojiDiscoveryJob.perform_later(domain)
      redirect_to config_custom_emojis_path(tab: 'remote'), notice: "#{domain} からの絵文字発見を開始しました"
    else
      # 全ドメインからの発見
      RemoteEmojiDiscoveryJob.perform_later
      redirect_to config_custom_emojis_path(tab: 'remote'), notice: '接触済みドメインからの絵文字発見を開始しました'
    end
  end

  # === Relay Management Actions ===

  # POST /config/relays
  def create_relay
    inbox_url = params[:inbox_url]&.strip

    if inbox_url.blank?
      redirect_to config_relays_path, alert: 'リレーのinbox URLを入力してください'
      return
    end

    relay = Relay.new(inbox_url: inbox_url, state: 'idle')

    if relay.save
      redirect_to config_relays_path, notice: 'リレーが追加されました'
    else
      redirect_to config_relays_path, alert: "リレーの追加に失敗しました: #{relay.errors.full_messages.join(', ')}"
    end
  end

  # PATCH /config/relays/:id
  def update_relay
    relay = Relay.find(params[:id])
    action = params[:action_type] || params[:relay]&.dig(:action)

    case action
    when 'enable'
      enable_relay(relay)
    when 'disable'
      disable_relay(relay)
    else
      redirect_to config_relays_path, alert: '無効な操作です'
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to config_relays_path, alert: 'リレーが見つかりません'
  end

  # DELETE /config/relays/:id
  def destroy_relay
    relay = Relay.find(params[:id])

    # 接続済みの場合は先に切断
    if relay.accepted?
      unfollow_service = RelayUnfollowService.new
      unfollow_service.call(relay)
    end

    if relay.destroy
      redirect_to config_relays_path, notice: 'リレーが削除されました'
    else
      redirect_to config_relays_path, alert: 'リレーの削除に失敗しました'
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to config_relays_path, alert: 'リレーが見つかりません'
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

    actor_params = params.expect(actor: [:note, :avatar, :display_name, { fields: %i[name value] }])

    # fieldsパラメータの再構成（配列形式からハッシュの配列へ）
    if params[:actor][:fields].present?
      fields_array = []
      params[:actor][:fields].each do |field|
        fields_array << { name: field[:name], value: field[:value] } if field[:name].present? || field[:value].present?
      end
      actor_params[:fields] = fields_array.to_json if fields_array.any?
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
    File.write(config_file, updated_config.to_yaml)
  end

  def config_params
    return nil unless params[:config]

    params.expect(
      config: %i[instance_name
                 instance_description
                 instance_contact_email
                 instance_maintainer
                 blog_footer
                 background_color]
    )
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
    case key
    when 'background_color'
      stored_config[key] || '#fdfbfb'
    when 'instance_name'
      stored_config[key] || 'letter'
    when 'instance_description'
      stored_config[key] || 'General Letter Publication System based on ActivityPub'
    when 'instance_contact_email'
      stored_config[key] || 'admin@localhost'
    when 'instance_maintainer'
      stored_config[key] || 'letter Administrator'
    when 'blog_footer'
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

  def base_emoji_scope_for_tab(tab)
    scope = CustomEmoji.includes(:image_attachment)

    scope = case tab
            when 'local'
              scope.local
            when 'remote'
              scope.remote
            else
              scope.local # デフォルトはローカル
            end

    scope.order(created_at: :desc)
  end

  def apply_emoji_filters(scope)
    scope = filter_by_category(scope)
    scope = filter_by_search(scope)
    scope = filter_by_domain(scope)
    paginate_emojis(scope)
  end

  def filter_by_category(scope)
    return scope if params[:enabled].blank?

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
    return scope if params[:q].blank?

    search_term = "%#{params[:q].upcase}%"
    scope.where('UPPER(shortcode) LIKE ? OR UPPER(domain) LIKE ?', search_term, search_term)
  end

  def filter_by_domain(scope)
    return scope if params[:domain].blank?

    scope.where(domain: params[:domain])
  end

  def paginate_emojis(scope)
    page = params[:page]&.to_i || 1
    per_page = 20
    offset = (page - 1) * per_page

    @current_page = page
    @total_count = scope.count
    @total_pages = (@total_count.to_f / per_page).ceil
    @has_next_page = page < @total_pages
    @has_prev_page = page > 1

    scope.offset(offset).limit(per_page)
  end

  def custom_emoji_params
    params.expect(custom_emoji: %i[shortcode domain image disabled visible_in_picker])
  end

  def enable_relay(relay)
    if relay.idle?
      # ActivityPub Follow アクティビティを送信
      follow_service = RelayFollowService.new
      success = follow_service.call(relay)

      if success
        redirect_to config_relays_path, notice: 'リレーへの接続を開始しました'
      else
        redirect_to config_relays_path, alert: "リレーへの接続に失敗しました: #{relay.last_error}"
      end
    else
      redirect_to config_relays_path, alert: 'このリレーは既に処理中です'
    end
  end

  def disable_relay(relay)
    if relay.accepted?
      # ActivityPub Undo Follow アクティビティを送信
      unfollow_service = RelayUnfollowService.new
      success = unfollow_service.call(relay)

      if success
        redirect_to config_relays_path, notice: 'リレーから切断しました'
      else
        redirect_to config_relays_path, alert: "リレーからの切断に失敗しました: #{relay.last_error}"
      end
    else
      relay.update!(state: 'idle')
      redirect_to config_relays_path, notice: 'リレーの状態をリセットしました'
    end
  end
end
