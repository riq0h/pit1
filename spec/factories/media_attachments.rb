# frozen_string_literal: true

FactoryBot.define do
  factory :media_attachment do
    association :actor
    association :object

    filename { 'test-image.jpg' }
    content_type { 'image/jpeg' }
    file_size { 1024 * 100 } # 100KB
    file_url { 'https://example.com/media/test-image.jpg' }
    mime_type { 'image/jpeg' }
    media_type { 'image' }

    width { 800 }
    height { 600 }
    blurhash { 'L6PZfSi_.AyE_3t7t7R**0o#DgR4' }
    description { 'A test image for pit1' }
    processed { true }

    metadata do
      {
        original: {
          width: width,
          height: height,
          size: "#{width}x#{height}",
          aspect: width.to_f / height
        }
      }
    end

    trait :image do
      media_type { 'image' }
      content_type { 'image/jpeg' }
      mime_type { 'image/jpeg' }
      filename { 'image.jpg' }
      file_size { 1024 * 100 } # 100KB
      width { 800 }
      height { 600 }
    end

    trait :video do
      media_type { 'video' }
      content_type { 'video/mp4' }
      mime_type { 'video/mp4' }
      filename { 'video.mp4' }
      file_size { 1024 * 1024 * 10 } # 10MB
      width { 1920 }
      height { 1080 }
      blurhash { 'L4R:8|00fQ00fQfQfQfQfQfQfQfQ' }
    end

    trait :audio do
      media_type { 'audio' }
      content_type { 'audio/mp3' }
      mime_type { 'audio/mp3' }
      filename { 'audio.mp3' }
      file_size { 1024 * 1024 * 5 } # 5MB
      width { nil }
      height { nil }
      blurhash { 'L2N]?U00Rj00RjRjRjRjRjRjRjRj' }
    end

    trait :document do
      media_type { 'document' }
      content_type { 'application/pdf' }
      mime_type { 'application/pdf' }
      filename { 'document.pdf' }
      file_size { 1024 * 512 } # 512KB
      width { nil }
      height { nil }
      blurhash { nil }
    end

    trait :large do
      file_size { 1024 * 1024 * 50 } # 50MB
    end

    trait :with_thumbnail do
      thumbnail_url { 'https://example.com/media/test-image-thumb.jpg' }
    end

    trait :unprocessed do
      processed { false }
      blurhash { nil }
      width { nil }
      height { nil }
    end

    trait :remote do
      storage_path { nil }
      file_url { 'https://remote.example/media/remote-file.jpg' }
      association :actor, :remote
    end
  end
end
