# frozen_string_literal: true

class UrlFilenameExtractor
  def self.extract(url)
    return 'unknown_file' if url.blank?

    uri = URI.parse(url)
    filename = File.basename(uri.path)
    filename.presence || 'unknown_file'
  rescue URI::InvalidURIError
    'unknown_file'
  end
end
