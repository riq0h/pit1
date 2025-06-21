# frozen_string_literal: true

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

          # Mastodon v2仕様: 画像は同期、動画・音声は非同期処理
          if media_attachment.image?
            render json: serialized_media_attachment(media_attachment), status: :ok
          else
            # TODO: 大きなメディアファイルの非同期処理実装
            # 現在は同期処理として扱う
            render json: serialized_media_attachment(media_attachment), status: :accepted
          end
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

      def extract_file_metadata(_file, media_type)
        metadata = {}

        if media_type == 'image'
          # TODO: 実際の画像メタデータ抽出の実装 (ImageMagickなど)
          # 現在はダミーデータを使用
          metadata[:width] = 1920
          metadata[:height] = 1080
          metadata[:blurhash] = 'LEHV6nWB2yk8pyo0adR*.7kCMdnj'
        end

        metadata
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
