# frozen_string_literal: true

module ActivityBuilders
  class AttachmentBuilder
    def initialize(object)
      @object = object
    end

    def build
      @object.media_attachments.map do |attachment|
        {
          'type' => 'Document',
          'mediaType' => attachment.content_type,
          'url' => attachment.url,
          'name' => attachment.description || attachment.file_name,
          'width' => attachment.width,
          'height' => attachment.height,
          'blurhash' => attachment.blurhash
        }.compact
      end
    end
  end
end
