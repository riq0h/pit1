# frozen_string_literal: true

class MediaTypeDetector
  def self.determine(content_type, _filename = nil)
    return 'image' if content_type&.start_with?('image/')
    return 'video' if content_type&.start_with?('video/')
    return 'audio' if content_type&.start_with?('audio/')

    'document'
  end
end
