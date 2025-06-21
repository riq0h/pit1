# frozen_string_literal: true

class StatusEdit < ApplicationRecord
  belongs_to :object, class_name: 'ActivityPubObject', primary_key: :id

  # Rails 8のJSONフィールド定義
  attribute :media_ids, :json, default: -> { [] }
  attribute :media_descriptions, :json, default: -> { [] }
  attribute :poll_options, :json, default: -> { [] }

  validates :created_at, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :for_object, ->(object_id) { where(object_id: object_id) }

  before_validation :set_defaults, on: :create
  before_validation :generate_snowflake_id, on: :create

  # 編集履歴エントリを作成
  def self.create_snapshot(object)
    create!(
      object: object,
      content: object.content,
      content_plaintext: object.content_plaintext,
      summary: object.summary,
      sensitive: object.sensitive,
      language: object.language,
      media_ids: object.media_attachments.pluck(:id),
      media_descriptions: object.media_attachments.pluck(:description)
    )
  end

  # 表示用のメディア情報
  def media_attachments_data
    return [] if media_ids.blank?

    MediaAttachment.where(id: media_ids).map do |attachment|
      {
        id: attachment.id.to_s,
        type: attachment.media_type,
        url: attachment.url,
        preview_url: attachment.preview_url,
        description: attachment.description,
        meta: {
          original: {
            width: attachment.width,
            height: attachment.height
          }
        }
      }
    end
  end

  private

  def set_defaults
    self.created_at ||= Time.current
  end

  def generate_snowflake_id
    return if id.present?

    self.id = Letter::Snowflake.generate
  end
end
