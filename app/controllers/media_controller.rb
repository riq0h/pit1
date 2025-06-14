# frozen_string_literal: true

class MediaController < ApplicationController
  before_action :set_media_attachment, only: %i[show thumbnail]

  # GET /media/:id
  def show
    return head :not_found unless @media_attachment

    file_path = Rails.root.join('storage', 'media', @media_attachment.storage_path)
    return head :not_found unless File.exist?(file_path)
    return head :not_found unless valid_storage_path?(@media_attachment.storage_path)

    send_file file_path,
              type: @media_attachment.content_type,
              disposition: 'inline',
              filename: sanitize_filename(@media_attachment.file_name)
  end

  # GET /media/:id/thumb
  def thumbnail
    return head :not_found unless @media_attachment

    file_path = Rails.root.join('storage', 'media', @media_attachment.storage_path)
    return head :not_found unless File.exist?(file_path)
    return head :not_found unless valid_storage_path?(@media_attachment.storage_path)

    # For now, return the original file (in production, use actual thumbnails)
    send_file file_path,
              type: @media_attachment.content_type,
              disposition: 'inline',
              filename: sanitize_filename("thumb_#{@media_attachment.file_name}")
  end

  private

  def set_media_attachment
    @media_attachment = MediaAttachment.find_by(id: params[:id])
  end

  def valid_storage_path?(storage_path)
    # パストラバーサル攻撃を防ぐ
    return false if storage_path.include?('..')
    return false if storage_path.start_with?('/')

    # ファイル名の形式を検証（タイムスタンプ_ランダム文字列.拡張子）
    storage_path.match?(/\A\d+_[a-f0-9]+\.[a-z0-9]+\z/i)
  end

  def sanitize_filename(filename)
    # ファイル名から危険な文字を除去
    filename.gsub(/[^\w\-_\.]/, '_')
  end
end
