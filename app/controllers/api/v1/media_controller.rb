# frozen_string_literal: true

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
        rescue StandardError => e
          Rails.logger.error "Media upload failed: #{e.message}"
          render json: { error: 'Media upload failed', details: e.message }, status: :unprocessable_entity
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
        storage_path = save_file_to_storage(file)
        metadata = extract_file_metadata(file, file_info[:media_type])

        build_media_attachment(file_info, storage_path, metadata)
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

      def build_media_attachment(file_info, storage_path, metadata)
        media_attachment = create_media_attachment_record(file_info, storage_path, metadata)
        save_and_update_remote_url(media_attachment)
        media_attachment
      end

      def create_media_attachment_record(file_info, storage_path, metadata)
        current_user.media_attachments.build(
          file_name: file_info[:filename],
          content_type: file_info[:content_type],
          file_size: file_info[:file_size],
          storage_path: storage_path,
          media_type: file_info[:media_type],
          width: metadata[:width],
          height: metadata[:height],
          blurhash: metadata[:blurhash],
          description: params[:description],
          metadata: metadata.to_json,
          processed: true
        )
      end

      def save_and_update_remote_url(media_attachment)
        # 一時的にremote_urlを設定してバリデーションを通す
        media_attachment.remote_url = 'temp'
        media_attachment.save!

        # IDが生成された後に正しいremote_urlを設定
        media_attachment.update!(remote_url: generate_file_url(media_attachment.id))
      end

      def save_file_to_storage(file)
        # 一意なファイル名を生成
        timestamp = Time.current.to_i
        random_id = SecureRandom.hex(8)
        extension = File.extname(file.original_filename)
        unique_filename = "#{timestamp}_#{random_id}#{extension}"

        # 保存パス（実際の実装では設定可能にする）
        storage_dir = Rails.root.join('storage', 'media')
        FileUtils.mkdir_p(storage_dir)

        storage_path = storage_dir.join(unique_filename)

        # ファイルを保存
        File.binwrite(storage_path, file.read)

        unique_filename
      end

      def generate_file_url(media_id)
        # 本来はCDNやS3のURLを生成
        # .envから設定されたActivityPubドメインを使用
        base_url = Rails.application.config.activitypub.base_url
        "#{base_url}/media/#{media_id}"
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

      def extract_file_metadata(_file, media_type)
        metadata = {}

        if media_type == 'image'
          # 画像のメタデータを抽出（実際の実装ではImageMagickなどを使用）
          metadata[:width] = 1920  # ダミーデータ
          metadata[:height] = 1080 # ダミーデータ
          metadata[:blurhash] = 'LEHV6nWB2yk8pyo0adR*.7kCMdnj' # ダミーデータ
        end

        metadata
      end

      def media_update_params
        params.permit(:description)
      end

      def serialized_media_attachment(media)
        {
          id: media.id.to_s,
          type: media.media_type,
          url: media.remote_url,
          preview_url: media.remote_url,
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
