# frozen_string_literal: true

# リモート画像をバックグラウンドでキャッシュするジョブ
class RemoteImageCacheJob < ApplicationJob
  queue_as :default

  # リトライ設定
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(media_attachment_id)
    media_attachment = MediaAttachment.find_by(id: media_attachment_id)
    return unless media_attachment

    # 既にファイルが添付されている場合はスキップ
    return if media_attachment.file.attached?

    # リモートURLがない場合はスキップ
    return if media_attachment.remote_url.blank?

    # 画像をキャッシュ
    success = media_attachment.cache_remote_image!

    if success
      Rails.logger.info "Successfully cached remote image: #{media_attachment.remote_url}"
    else
      Rails.logger.warn "Failed to cache remote image: #{media_attachment.remote_url}"
    end
  end
end
