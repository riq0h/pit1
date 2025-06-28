# frozen_string_literal: true

FactoryBot.define do
  factory :media_attachment do
    actor
    object { nil }
    media_type { 'image' }
    remote_url { 'https://example.com/image.jpg' }
    description { 'Test image' }
    file_name { 'test_image.jpg' }
    content_type { 'image/jpeg' }
    file_size { 1024 }
    width { 640 }
    height { 480 }
    processed { true }

    trait :video do
      media_type { 'video' }
      remote_url { 'https://example.com/video.mp4' }
      file_name { 'test_video.mp4' }
      content_type { 'video/mp4' }
      file_size { 10_240 }
    end

    trait :audio do
      media_type { 'audio' }
      remote_url { 'https://example.com/audio.mp3' }
      file_name { 'test_audio.mp3' }
      content_type { 'audio/mpeg' }
      file_size { 5_120 }
    end

    trait :unprocessed do
      processed { false }
    end
  end
end
