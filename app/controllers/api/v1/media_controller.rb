# frozen_string_literal: true

require 'mini_magick'
require 'blurhash'

module Api
  module V1
    class MediaController < Api::BaseController
      before_action :doorkeeper_authorize!

      # GET /api/v1/media/:id
      def show
        media_attachment = current_user.media_attachments.find(params[:id])
        render json: serialized_media_attachment(media_attachment)
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Media not found' }, status: :not_found
      end

      # POST /api/v1/media
      def create
        return render json: { error: 'This action requires authentication' }, status: :unauthorized unless current_user

        file = params[:file]
        return render json: { error: 'File parameter is required' }, status: :unprocessable_entity unless file

        begin
          media_attachment = create_media_attachment(file)
          render json: serialized_media_attachment(media_attachment), status: :created
        rescue ActiveRecord::RecordInvalid => e
          Rails.logger.error "Media upload validation failed: #{e.message}"
          render json: { error: e.record.errors.full_messages.join(', ') }, status: :unprocessable_entity
        rescue StandardError => e
          Rails.logger.error "Media upload failed: #{e.message}"
          render json: { error: e.message }, status: :unprocessable_entity
        end
      end

      # PUT /api/v1/media/:id
      def update
        media_attachment = current_user.media_attachments.find(params[:id])

        if media_attachment.update(media_update_params)
          render json: serialized_media_attachment(media_attachment)
        else
          render json: {
            error: 'Validation failed',
            details: media_attachment.errors.full_messages
          }, status: :unprocessable_entity
        end
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Media not found' }, status: :not_found
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
          processed: true
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
          'document'
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

        if media_type == 'image'
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

        metadata
      end

      def generate_blurhash(image)
        # 画像を小さくリサイズしてBlurhash生成の高速化
        image.resize '200x200>'
        
        # RGBピクセルデータを取得
        pixels = image.get_pixels
        width = image.width
        height = image.height
        
        # ピクセルデータをBlurhash用にフラット化
        pixel_data = pixels.flatten.map(&:to_i)
        
        # Blurhashを生成（4x4コンポーネント）
        Blurhash.encode(width, height, pixel_data, x_components: 4, y_components: 4)
      rescue StandardError => e
        Rails.logger.warn "Failed to generate blurhash: #{e.message}"
        # デフォルトのBlurhash（灰色の平坦な画像）
        'LEHV6nWB2yk8pyo0adR*.7kCMdnj'
      end

      def media_update_params
        params.permit(:description)
      end

      def serialized_media_attachment(media)
        {
          id: media.id.to_s,
          type: media.media_type,
          url: media.url,
          preview_url: media.preview_url,
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
