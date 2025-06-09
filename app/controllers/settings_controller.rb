# frozen_string_literal: true

class SettingsController < ApplicationController
  before_action :authenticate_user!

  # GET /settings
  def show
    @settings = current_instance_settings
  end

  # PATCH /settings
  def update
    if update_instance_settings
      redirect_to settings_path, notice: I18n.t('settings.updated')
    else
      @settings = current_instance_settings
      flash.now[:alert] = I18n.t('settings.update_failed')
      render :show, status: :unprocessable_entity
    end
  end

  private

  def current_instance_settings
    build_base_settings.merge(build_activitypub_settings)
  end

  def build_base_settings
    {
      instance_name: Rails.application.config.instance_name,
      instance_description: Rails.application.config.instance_description,
      instance_contact_email: Rails.application.config.instance_contact_email,
      instance_maintainer: Rails.application.config.instance_maintainer
    }
  end

  def build_activitypub_settings
    {
      activitypub_domain: Rails.application.config.activitypub.domain,
      character_limit: Rails.application.config.activitypub.character_limit,
      max_accounts: Rails.application.config.activitypub.max_accounts,
      federation_enabled: Rails.application.config.activitypub.federation_enabled
    }
  end

  def update_instance_settings
    # 実際の設定更新は環境変数やDBに保存する実装を後で追加
    # 現状では更新されたことを示すためにtrueを返す
    true
  end

  def settings_params
    params.expect(
      settings: %i[instance_name
                   instance_description
                   instance_contact_email
                   instance_maintainer
                   federation_enabled]
    )
  end
end
