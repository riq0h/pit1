# frozen_string_literal: true

module MediaAttachmentCreation
  extend ActiveSupport::Concern

  private

  def create_media_attachment(file, processing_status: nil)
    MediaAttachmentCreationService.new(
      user: current_user,
      description: params[:description],
      processing_status: processing_status
    ).create_from_file(file)
  end
end
