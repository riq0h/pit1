# frozen_string_literal: true

require 'mini_magick'

class MediaProcessingJob < ApplicationJob
  queue_as :media_processing

  def perform(media_attachment_id)
    media_attachment = MediaAttachment.find(media_attachment_id)
    
    Rails.logger.info "Processing media attachment #{media_attachment_id}"
    
    begin
      # メディアファイルの処理を実行
      process_media_attachment(media_attachment)
      
      # 処理完了をマーク
      media_attachment.update!(
        processed: true,
        processing_status: 'completed'
      )
      
      Rails.logger.info "Media processing completed for #{media_attachment_id}"
    rescue StandardError => e
      Rails.logger.error "Media processing failed for #{media_attachment_id}: #{e.message}"
      
      media_attachment.update!(
        processed: false,
        processing_status: 'failed'
      )
      
      raise e
    end
  end

  private

  def process_media_attachment(media_attachment)
    case media_attachment.media_type
    when 'video'
      process_video(media_attachment)
    when 'audio'
      process_audio(media_attachment)
    end
  end

  def process_video(media_attachment)
    Rails.logger.info "Processing video: #{media_attachment.file_name}"
    
    return unless media_attachment.file.attached?
    
    begin
      # 動画からサムネイルを生成
      generate_video_thumbnail(media_attachment)
      
      # 動画のメタデータを抽出
      extract_video_metadata(media_attachment)
      
    rescue StandardError => e
      Rails.logger.error "Video processing failed: #{e.message}"
      raise e
    end
  end

  def process_audio(media_attachment)
    Rails.logger.info "Processing audio: #{media_attachment.file_name}"
    
    return unless media_attachment.file.attached?
    
    begin
      # 音声のメタデータを抽出
      extract_audio_metadata(media_attachment)
      
    rescue StandardError => e
      Rails.logger.error "Audio processing failed: #{e.message}"
      raise e
    end
  end

  def generate_video_thumbnail(media_attachment)
    media_attachment.file.open do |file|
      # FFMpegを使用して動画の最初のフレームからサムネイルを生成
      image = MiniMagick::Image.open(file.path + '[0]')
      image.resize '400x400>'
      image.format 'jpeg'
      
      # サムネイル情報をメタデータに保存
      metadata = JSON.parse(media_attachment.metadata.presence || '{}')
      metadata['thumbnail'] = {
        width: image.width,
        height: image.height
      }
      
      # 動画の寸法も取得
      video_info = MiniMagick::Image.open(file.path)
      metadata['original'] = {
        width: video_info.width,
        height: video_info.height
      }
      
      media_attachment.update!(
        width: video_info.width,
        height: video_info.height,
        metadata: metadata.to_json
      )
    end
  end

  def extract_video_metadata(media_attachment)
    media_attachment.file.open do |file|
      # MiniMagickを使用して動画の詳細情報を取得
      video = MiniMagick::Image.open(file.path)
      
      metadata = JSON.parse(media_attachment.metadata.presence || '{}')
      
      # フレームレートを取得
      identify_output = MiniMagick::Tool::Identify.new do |identify|
        identify.format '%[fx:1/delay*100]'
        identify << file.path + '[0]'
      end
      framerate = identify_output.to_f.round(2)
      
      # 動画の長さを取得（フレーム数から計算）
      frame_count_output = MiniMagick::Tool::Identify.new do |identify|
        identify.format '%[scenes]'
        identify << file.path
      end
      frame_count = frame_count_output.to_i
      
      duration = frame_count > 0 && framerate > 0 ? (frame_count / framerate).round(2) : 0
      
      metadata['duration'] = duration
      metadata['framerate'] = framerate
      metadata['frame_count'] = frame_count
      
      media_attachment.update!(metadata: metadata.to_json)
    end
  rescue StandardError => e
    Rails.logger.warn "Could not extract detailed video metadata: #{e.message}"
    # 基本的なメタデータのみ設定
    metadata = JSON.parse(media_attachment.metadata.presence || '{}')
    metadata['duration'] = 0
    metadata['framerate'] = 0
    media_attachment.update!(metadata: metadata.to_json)
  end

  def extract_audio_metadata(media_attachment)
    media_attachment.file.open do |file|
      # MiniMagickを使用して音声ファイルの情報を取得
      audio = MiniMagick::Image.open(file.path)
      
      metadata = JSON.parse(media_attachment.metadata.presence || '{}')
      
      # 音声の長さを取得
      duration_output = MiniMagick::Tool::Identify.new do |identify|
        identify.format '%[fx:t]'
        identify << file.path
      end
      duration = duration_output.to_f.round(2)
      
      # サンプルレートとビットレートの取得を試行
      begin
        info_output = MiniMagick::Tool::Identify.new do |identify|
          identify.verbose
          identify << file.path
        end
        
        # サンプルレートを抽出
        sample_rate = info_output.match(/Audio.*?(\d+) Hz/)?.[1]&.to_i
        
        metadata['duration'] = duration
        metadata['sample_rate'] = sample_rate
        
      rescue StandardError
        # 詳細情報が取得できない場合は基本情報のみ
        metadata['duration'] = duration
      end
      
      media_attachment.update!(metadata: metadata.to_json)
    end
  rescue StandardError => e
    Rails.logger.warn "Could not extract audio metadata: #{e.message}"
    # フォールバック
    metadata = JSON.parse(media_attachment.metadata.presence || '{}')
    metadata['duration'] = 0
    media_attachment.update!(metadata: metadata.to_json)
  end
end