# frozen_string_literal: true

module Admin
  class CustomEmojisController < Admin::BaseController
    before_action :set_custom_emoji, only: %i[show edit update destroy enable disable]

    def index
      @custom_emojis = base_emoji_scope
      @custom_emojis = apply_emoji_filters(@custom_emojis)
    end

    def show; end

    def new
      @custom_emoji = CustomEmoji.new
    end

    def edit; end

    def create
      @custom_emoji = CustomEmoji.new(custom_emoji_params)

      if @custom_emoji.save
        redirect_to admin_custom_emojis_path, notice: t('custom_emojis.created')
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      if @custom_emoji.update(custom_emoji_params)
        redirect_to admin_custom_emojis_path, notice: t('custom_emojis.updated')
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @custom_emoji.image.purge if @custom_emoji.image.attached?
      @custom_emoji.delete
      redirect_to admin_custom_emojis_path, notice: t('custom_emojis.deleted')
    end

    def enable
      @custom_emoji.update(disabled: false)
      redirect_to admin_custom_emojis_path, notice: t('custom_emojis.enabled')
    end

    def disable
      @custom_emoji.update(disabled: true)
      redirect_to admin_custom_emojis_path, notice: t('custom_emojis.disabled')
    end

    def bulk_action
      message = process_bulk_emoji_action(params[:action_type], params[:emoji_ids])
      redirect_to admin_custom_emojis_path, **message
    end

    private

    def base_emoji_scope
      CustomEmoji.local.includes(:image_attachment).alphabetical.page(params[:page])
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

    def set_custom_emoji
      @custom_emoji = CustomEmoji.find(params[:id])
    end

    def custom_emoji_params
      params.expect(custom_emoji: %i[shortcode image category_id])
    end
  end
end
