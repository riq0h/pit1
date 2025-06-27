# frozen_string_literal: true

class ScheduledStatus < ApplicationRecord
  belongs_to :actor
  has_many_attached :media_attachments

  validates :scheduled_at, presence: true
  validates :params, presence: true
  validate :validate_scheduled_time
  validate :validate_params_format

  after_create :schedule_publish_job

  scope :due, -> { where(scheduled_at: ..Time.current) }
  scope :pending, -> { where('scheduled_at > ?', Time.current) }
  scope :for_actor, ->(actor) { where(actor: actor) }

  def self.process_due_statuses!
    due.find_each do |scheduled_status|
      scheduled_status.publish!
    rescue StandardError => e
      Rails.logger.error "Failed to publish scheduled status #{scheduled_status.id}: #{e.message}"
      # エラー時は削除せず再試行または手動処理に委ねる
    end
  end

  def publish!
    ActiveRecord::Base.transaction do
      # StatusServiceを使用してステータスを作成
      status_params = prepare_status_params

      # ステータスを作成
      status = actor.objects.create!(
        object_type: 'Note',
        content: status_params[:status],
        visibility: status_params[:visibility] || 'public',
        sensitive: status_params[:sensitive] || false,
        summary: status_params[:spoiler_text],
        in_reply_to_ap_id: status_params[:in_reply_to_id],
        published_at: Time.current,
        local: true,
        ap_id: generate_ap_id
      )

      # メディアが存在する場合は添付
      attach_media_to_status(status) if media_attachment_ids.present?

      # 投票が存在する場合は処理
      create_poll_for_status(status) if status_params[:poll].present?

      # スケジュール済みステータスを削除
      destroy!

      status
    end
  end

  def due?
    scheduled_at <= Time.current
  end

  def pending?
    scheduled_at > Time.current
  end

  def to_mastodon_api
    {
      id: id.to_s,
      scheduled_at: scheduled_at.iso8601,
      params: serialize_params,
      media_attachments: serialize_media_attachments
    }
  end

  private

  def validate_scheduled_time
    return unless scheduled_at

    min_time = 5.minutes.from_now
    max_time = 2.years.from_now

    if scheduled_at < min_time
      errors.add(:scheduled_at, 'must be at least 5 minutes from now')
    elsif scheduled_at > max_time
      errors.add(:scheduled_at, 'cannot be more than 2 years from now')
    end
  end

  def validate_params_format
    return unless params

    unless params.is_a?(Hash)
      errors.add(:params, 'must be a hash')
      return
    end

    errors.add(:params, 'must include status text') if params['status'].blank?

    return unless params['status'].to_s.length > 9999

    errors.add(:params, 'status text too long (maximum 9999 characters)')
  end

  def prepare_status_params
    base_params = params.dup

    # 適切なデフォルト値を確保
    base_params['visibility'] ||= 'public'
    base_params['sensitive'] ||= false

    base_params.symbolize_keys
  end

  def generate_ap_id
    base_url = Rails.application.config.activitypub.base_url
    "#{base_url}/users/#{actor.username}/statuses/#{SecureRandom.uuid}"
  end

  def attach_media_to_status(status)
    return unless media_attachment_ids.is_a?(Array)

    media_attachments = MediaAttachment.where(id: media_attachment_ids, actor: actor)
    media_attachments.update_all(status_id: status.id)
  end

  def create_poll_for_status(status)
    poll_params = params['poll']
    return unless poll_params.is_a?(Hash)

    # パラメータをシンボルキーに変換
    symbolized_params = poll_params.deep_symbolize_keys

    PollCreationService.create_for_status(status, symbolized_params)
  end

  def serialize_params
    base_params = params.except('poll').merge(
      poll: params['poll'] ? serialize_poll_params : nil
    ).compact

    # Mastodon API互換性のためtextフィールドも提供
    base_params['text'] = base_params['status'] if base_params['status'].present?

    # visibilityフィールドが必須のため、デフォルト値を確保
    base_params['visibility'] ||= 'public'

    base_params
  end

  def serialize_poll_params
    poll_params = params['poll']
    return nil unless poll_params

    {
      options: poll_params['options'],
      expires_in: poll_params['expires_in'],
      multiple: poll_params['multiple'] || false,
      hide_totals: poll_params['hide_totals'] || false
    }
  end

  def serialize_media_attachments
    return [] unless media_attachment_ids.is_a?(Array)

    MediaAttachment.where(id: media_attachment_ids, actor: actor).map do |attachment|
      {
        id: attachment.id.to_s,
        type: attachment.file_type,
        url: attachment.file_url,
        preview_url: attachment.preview_url,
        remote_url: nil,
        description: attachment.description,
        blurhash: attachment.blurhash
      }
    end
  end

  def schedule_publish_job
    PublishScheduledStatusJob.set(wait_until: scheduled_at).perform_later(id)
  end
end
