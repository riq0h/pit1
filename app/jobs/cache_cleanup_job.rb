# frozen_string_literal: true

# 期限切れのキャッシュとファイルをクリーンアップするジョブ
class CacheCleanupJob < ApplicationJob
  queue_as :low_priority

  def perform
    cleanup_expired_cache_files
    cleanup_orphaned_blobs
  end

  private

  def cleanup_expired_cache_files
    # Solid Cacheは delete_matched をサポートしていないため、
    # 期限切れのActive Storage Blobを直接検索してクリーンアップ
    expired_count = 0

    # 7日以上前のキャッシュファイルを検索
    cutoff_date = RemoteImageCacheService::CACHE_DURATION.ago

    # img/フォルダ内の古いBlobを検索
    old_blobs = ActiveStorage::Blob
                .where(created_at: ...cutoff_date)
                .where('key LIKE ?', 'img/%')

    old_blobs.find_each do |blob|
      # MediaAttachmentに関連付けられていないキャッシュファイルのみ削除
      attachments = ActiveStorage::Attachment.where(blob: blob)

      if attachments.empty? || attachments.all? { |att| att.record.is_a?(MediaAttachment) && !att.record.actor.local? }
        blob.purge
        expired_count += 1
      end
    end

    Rails.logger.info "Cache cleanup completed: #{expired_count} expired blobs processed"
  end

  def cleanup_orphaned_blobs
    # 7日以上前の、関連付けのないActive Storage Blobを削除
    orphaned_blobs = ActiveStorage::Blob
                     .where(created_at: ...7.days.ago)
                     .where('key LIKE ?', 'img/%')
                     .left_joins(:attachments)
                     .where(active_storage_attachments: { id: nil })

    orphaned_count = orphaned_blobs.count
    orphaned_blobs.find_each(&:purge)

    Rails.logger.info "Orphaned blob cleanup completed: #{orphaned_count} blobs removed"
  end
end
