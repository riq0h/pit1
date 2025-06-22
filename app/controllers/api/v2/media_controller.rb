# frozen_string_literal: true

require 'mini_magick'
require 'blurhash'

module Api
  module V2
    class MediaController < Api::BaseController
      before_action :doorkeeper_authorize!, :require_user!

      # POST /api/v2/media
      def create
        file = params[:file]
        return render json: { error: 'File parameter is required' }, status: :unprocessable_entity unless file

        begin
          media_attachment = create_media_attachment(file)

          # 全て同期処理で即座に完了
          render json: serialized_media_attachment(media_attachment), status: :ok
        rescue StandardError => e
          Rails.logger.error "Media upload failed: #{e.message}"
          render json: { error: 'Media upload failed', details: e.message }, status: :unprocessable_entity
        end
      end

      private

      def create_media_attachment(file)
        file_info = extract_file_info(file)
        metadata = extract_file_metadata(file, file_info[:media_type])

        build_media_attachment_with_active_storage(file, file_info, metadata)
      end

      def extract_file_info(file)
        filename = file.original_filename
        content_type = file.content_type || detect_content_type(filename)
        {
          filename: filename,
          content_type: content_type,
          file_size: file.size,
          media_type: determine_media_type(content_type, filename)
        }
      end

      def build_media_attachment_with_active_storage(file, file_info, metadata)
        media_attachment = create_media_attachment_record_with_active_storage(file, file_info, metadata)
        media_attachment.save!
        media_attachment
      end

      def create_media_attachment_record_with_active_storage(file, file_info, metadata)
        media_attachment = current_user.media_attachments.build(
          file_name: file_info[:filename],
          content_type: file_info[:content_type],
          file_size: file_info[:file_size],
          media_type: file_info[:media_type],
          width: metadata[:width],
          height: metadata[:height],
          blurhash: metadata[:blurhash],
          description: params[:description],
          metadata: metadata.to_json,
          processed: true,
          processing_status: 'completed'
        )

        media_attachment.file.attach(file)
        media_attachment
      end

      def determine_media_type(content_type, _filename)
        case content_type
        when /^image\//
          'image'
        when /^video\//
          'video'
        when /^audio\//
          'audio'
        else
          'unknown'
        end
      end

      def detect_content_type(filename)
        extension = File.extname(filename).downcase.delete('.')

        case extension
        when *MediaAttachment::IMAGE_FORMATS
          "image/#{extension == 'jpg' ? 'jpeg' : extension}"
        when *MediaAttachment::VIDEO_FORMATS
          "video/#{extension}"
        when *MediaAttachment::AUDIO_FORMATS
          "audio/#{extension}"
        else
          'application/octet-stream'
        end
      end

      def extract_file_metadata(file, media_type)
        metadata = {}

        case media_type
        when 'image'
          extract_image_metadata(file, metadata)
        when 'video'
          extract_basic_video_metadata(file, metadata)
        when 'audio'
          extract_basic_audio_metadata(file, metadata)
        end

        metadata
      end

      def extract_image_metadata(file, metadata)
        begin
          # MiniMagickを使用して画像のメタデータを抽出
          image = MiniMagick::Image.read(file.read)
          metadata[:width] = image.width
          metadata[:height] = image.height

          # Blurhashを生成
          metadata[:blurhash] = generate_blurhash(image)

          # ファイルポインタをリセット
          file.rewind
        rescue StandardError => e
          Rails.logger.warn "Failed to extract image metadata: #{e.message}"
          # フォールバック値
          metadata[:width] = nil
          metadata[:height] = nil
          metadata[:blurhash] = nil
        end
      end

      def extract_basic_video_metadata(file, metadata)
        begin
          # 動画の1フレーム目からサムネイルを生成
          temp_file = file.tempfile
          image = MiniMagick::Image.open(temp_file.path + '[0]')
          
          metadata[:width] = image.width
          metadata[:height] = image.height
          metadata[:duration] = 0
          
          # サムネイル用にリサイズしてBlurhash生成
          thumbnail = image.dup
          thumbnail.resize '200x200>'  
          metadata[:blurhash] = generate_blurhash(thumbnail)
          
        rescue StandardError => e
          Rails.logger.warn "Could not extract video thumbnail: #{e.message}"
          # フォールバック: デフォルト値
          metadata[:width] = 640
          metadata[:height] = 480
          metadata[:duration] = 0
          metadata[:blurhash] = 'LEHV6nWB2yk8pyo0adR*.7kCMdnj'
        end
      end

      def extract_basic_audio_metadata(file, metadata)
        # 音声の基本情報のみ設定（外部依存なし）
        metadata[:duration] = 0
        metadata[:sample_rate] = 44100
      end

      def generate_blurhash(image)
        # 画像をリサイズしてピクセルデータを取得
        resized_image = image.dup
        resized_image.resize '200x200>'

        pixels = resized_image.get_pixels
        width = resized_image.width
        height = resized_image.height

        # ピクセルデータをBlurhash用にフラット化
        pixel_data = pixels.flatten.map(&:to_i)

        # Blurhashを生成
        Blurhash.encode(width, height, pixel_data, x_components: 4, y_components: 4)
      rescue StandardError => e
        Rails.logger.warn "Failed to generate blurhash: #{e.message}"
        'LEHV6nWB2yk8pyo0adR*.7kCMdnj'
      end

      def serialized_media_attachment(media)
        {
          id: media.id.to_s,
          type: media.media_type,
          url: media.url || '',
          preview_url: media.preview_url || '',
          remote_url: media.remote_url,
          meta: build_media_metadata(media),
          description: media.description,
          blurhash: media.blurhash
        }
      end

      def build_media_metadata(media)
        {
          original: build_original_metadata(media),
          small: build_small_metadata(media)
        }
      end

      def build_original_metadata(media)
        return {} unless media.width && media.height

        {
          width: media.width,
          height: media.height,
          size: "#{media.width}x#{media.height}",
          aspect: (media.width.to_f / media.height).round(2)
        }
      end

      def build_small_metadata(media)
        return {} unless media.width && media.height

        if media.width > 400
          small_height = (media.height * 400 / media.width).round
          {
            width: 400,
            height: small_height,
            size: "400x#{small_height}",
            aspect: (media.width.to_f / media.height).round(2)
          }
        else
          build_original_metadata(media)
        end
      end
    end
  end
end
