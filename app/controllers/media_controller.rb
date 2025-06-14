# frozen_string_literal: true

class MediaController < ApplicationController
  before_action :set_media_attachment, only: %i[show thumbnail]

  # GET /media/:id
  def show
    return head :not_found unless @media_attachment

    file_path = Rails.root.join('storage', 'media', @media_attachment.storage_path)
    return head :not_found unless File.exist?(file_path)

    send_file file_path,
              type: @media_attachment.content_type,
              disposition: 'inline',
              filename: @media_attachment.file_name
  end

  # GET /media/:id/thumb
  def thumbnail
    return head :not_found unless @media_attachment

    file_path = Rails.root.join('storage', 'media', @media_attachment.storage_path)
    return head :not_found unless File.exist?(file_path)

    # For now, return the original file (in production, use actual thumbnails)
    send_file file_path,
              type: @media_attachment.content_type,
              disposition: 'inline',
              filename: "thumb_#{@media_attachment.file_name}"
  end

  private

  def set_media_attachment
    @media_attachment = MediaAttachment.find_by(id: params[:id])
  end
end
