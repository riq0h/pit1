# frozen_string_literal: true

class MediaAttachment < ApplicationRecord
  # === 定数 ===
  MEDIA_TYPES = %w[image video audio document].freeze
  IMAGE_FORMATS = %w[jpeg jpg png gif webp avif].freeze
  VIDEO_FORMATS = %w[mp4 webm mov avi].freeze
  AUDIO_FORMATS = %w[mp3 ogg wav flac m4a].freeze
  DOCUMENT_FORMATS = %w[pdf txt doc docx].freeze

  MAX_IMAGE_SIZE = 10.megabytes
  MAX_VIDEO_SIZE = 100.megabytes
  MAX_AUDIO_SIZE = 50.megabytes
  MAX_DOCUMENT_SIZE = 20.megabytes

  # 浮動小数点比較用の許容範囲
  FLOAT_TOLERANCE = 0.01

  # === バリデーション ===
  validates :media_type, presence: true, inclusion: { in: MEDIA_TYPES }
  validates :file_url, presence: true
  validates :file_size, presence: true, numericality: { greater_than: 0 }
  validates :mime_type, presence: true
  validates :filename, presence: true

  validate :validate_file_size_by_type
  validate :validate_mime_type_by_media_type

  # === アソシエーション ===
  belongs_to :actor, inverse_of: :media_attachments
  belongs_to :object, optional: true, inverse_of: :media_attachments

  # === スコープ ===
  scope :images, -> { where(media_type: 'image') }
  scope :videos, -> { where(media_type: 'video') }
  scope :audio, -> { where(media_type: 'audio') }
  scope :documents, -> { where(media_type: 'document') }
  scope :attached, -> { where.not(object_id: nil) }
  scope :unattached, -> { where(object_id: nil) }
  scope :recent, -> { order(created_at: :desc) }

  # === コールバック ===
  before_validation :set_defaults, on: :create
  before_validation :extract_metadata

  # === 判定メソッド ===

  def image?
    media_type == 'image'
  end

  def video?
    media_type == 'video'
  end

  def audio?
    media_type == 'audio'
  end

  def document?
    media_type == 'document'
  end

  def attached?
    object_id.present?
  end

  delegate :local?, to: :actor

  def remote?
    !local?
  end

  # === 表示用メソッド ===

  def display_name
    filename.presence || 'Untitled'
  end

  def file_extension
    return '' if filename.blank?

    File.extname(filename).downcase.delete('.')
  end

  def human_file_size
    return '0 B' if file_size.zero?

    units = %w[B KB MB GB TB]
    size = file_size.to_f
    unit_index = 0

    while size >= 1024 && unit_index < units.length - 1
      size /= 1024
      unit_index += 1
    end

    "#{size.round(1)} #{units[unit_index]}"
  end

  def preview_url
    return thumbnail_url if thumbnail_url.present?
    return file_url if image?

    # デフォルトのプレビューアイコン
    default_preview_icon_url
  end

  def aspect_ratio
    return nil unless width.present? && height.present? && height.positive?

    (width.to_f / height).round(2)
  end

  def landscape?
    return false unless aspect_ratio

    aspect_ratio > 1.0
  end

  def portrait?
    return false unless aspect_ratio

    aspect_ratio < 1.0
  end

  def square?
    return false unless aspect_ratio

    # 浮動小数点の安全な比較
    (aspect_ratio - 1.0).abs < FLOAT_TOLERANCE
  end

  # === ActivityPub関連メソッド ===

  def activitypub_document
    {
      type: 'Document',
      mediaType: mime_type,
      url: file_url,
      name: alt_text.presence || display_name,
      width: width,
      height: height
    }.tap do |doc|
      doc[:summary] = description if description.present?
    end
  end

  private

  def set_defaults
    self.processed = false if processed.nil?
    self.blurhash ||= generate_placeholder_blurhash
  end

  def extract_metadata
    return unless file_url.present? && !processed?

    # ファイル拡張子からmedia_typeを推測
    detect_media_type_from_filename if media_type.blank?

    # 基本的なメタデータ設定
    self.processed = true
  end

  def detect_media_type_from_filename
    ext = file_extension

    self.media_type = determine_media_type_by_extension(ext)
  end

  def determine_media_type_by_extension(ext)
    return 'image' if IMAGE_FORMATS.include?(ext)
    return 'video' if VIDEO_FORMATS.include?(ext)
    return 'audio' if AUDIO_FORMATS.include?(ext)
    return 'document' if DOCUMENT_FORMATS.include?(ext)

    'document'
  end

  def validate_file_size_by_type
    max_size = max_size_for_media_type

    return unless file_size > max_size

    errors.add(:file_size, "is too large for #{media_type} files (max: #{max_size / 1.megabyte}MB)")
  end

  def max_size_for_media_type
    case media_type
    when 'image'
      MAX_IMAGE_SIZE
    when 'video'
      MAX_VIDEO_SIZE
    when 'audio'
      MAX_AUDIO_SIZE
    else
      MAX_DOCUMENT_SIZE
    end
  end

  def validate_mime_type_by_media_type
    valid_formats = valid_formats_for_media_type

    return if valid_formats.empty?

    # MIME typeから拡張子を抽出してチェック
    format_from_mime = mime_type.split('/').last

    return if valid_formats.include?(format_from_mime)

    errors.add(:mime_type, "#{mime_type} is not supported for #{media_type} files")
  end

  def valid_formats_for_media_type
    case media_type
    when 'image'
      IMAGE_FORMATS
    when 'video'
      VIDEO_FORMATS
    when 'audio'
      AUDIO_FORMATS
    else
      DOCUMENT_FORMATS
    end
  end

  def default_preview_icon_url
    case media_type
    when 'video'
      '/icons/video-preview.svg'
    when 'audio'
      '/icons/audio-preview.svg'
    when 'document'
      '/icons/document-preview.svg'
    else
      '/icons/file-preview.svg'
    end
  end

  def generate_placeholder_blurhash
    # プレースホルダーとして単色のblurhashを生成
    case media_type
    when 'image'
      'L6PZfSi_.AyE_3t7t7R**0o#DgR4' # 薄いグレー
    when 'video'
      'L4R:8|00fQ00fQfQfQfQfQfQfQfQ' # 濃いグレー
    else
      'L2N]?U00Rj00RjRjRjRjRjRjRjRj' # 黒
    end
  end
end
