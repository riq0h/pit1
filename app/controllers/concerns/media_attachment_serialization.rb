# frozen_string_literal: true

module MediaAttachmentSerialization
  extend ActiveSupport::Concern

  private

  def serialized_media_attachment(media)
    {
      id: media.id.to_s,
      type: media.media_type,
      url: media.url || '',
      preview_url: media.preview_url || '',
      remote_url: media.remote_url,
      meta: build_media_meta(media),
      description: media.description,
      blurhash: media.blurhash
    }
  end
end
