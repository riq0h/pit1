# frozen_string_literal: true

class ContentTypeDetector
  MIME_TYPES = {
    # 画像
    '.jpg' => 'image/jpeg',
    '.jpeg' => 'image/jpeg',
    '.png' => 'image/png',
    '.gif' => 'image/gif',
    '.webp' => 'image/webp',
    '.heic' => 'image/heic',
    '.heif' => 'image/heif',
    '.avif' => 'image/avif',

    # ビデオ
    '.mp4' => 'video/mp4',
    '.webm' => 'video/webm',
    '.mov' => 'video/quicktime',
    '.ogg' => 'video/ogg',
    '.ogv' => 'video/ogg',

    # オーディオ
    '.mp3' => 'audio/mpeg',
    '.oga' => 'audio/ogg',
    '.wav' => 'audio/wave',
    '.flac' => 'audio/flac',
    '.opus' => 'audio/opus',
    '.weba' => 'audio/webm',
    '.m4a' => 'audio/mp4'
  }.freeze

  SUPPORTED_IMAGE_TYPES = %w[
    image/jpeg image/png image/gif image/webp
    image/heic image/heif image/avif
  ].freeze

  SUPPORTED_VIDEO_TYPES = %w[
    video/mp4 video/webm video/quicktime video/ogg
  ].freeze

  SUPPORTED_AUDIO_TYPES = %w[
    audio/mpeg audio/mp3 audio/ogg audio/vorbis
    audio/wave audio/wav audio/x-wav audio/x-pn-wave
    audio/flac audio/opus audio/webm audio/mp4
  ].freeze

  def self.detect_from_filename(filename)
    return 'application/octet-stream' if filename.blank?

    extension = File.extname(filename).downcase
    MIME_TYPES[extension] || 'application/octet-stream'
  end

  def self.supported_mime_types
    SUPPORTED_IMAGE_TYPES + SUPPORTED_VIDEO_TYPES + SUPPORTED_AUDIO_TYPES
  end

  def self.supported_image_types
    SUPPORTED_IMAGE_TYPES
  end

  def self.supported_video_types
    SUPPORTED_VIDEO_TYPES
  end

  def self.supported_audio_types
    SUPPORTED_AUDIO_TYPES
  end
end
