# frozen_string_literal: true

# 既存のActive Storageファイルを Cloudflare R2 に移行するジョブ
class MigrateToR2Job < ApplicationJob
  queue_as :default

  def perform(batch_size: 50)
    return unless r2_enabled?

    Rails.logger.info 'Starting migration of local files to Cloudflare R2'

    migrate_media_attachments(batch_size)
    migrate_custom_emojis(batch_size)
    migrate_actor_images(batch_size)

    Rails.logger.info 'Completed migration to Cloudflare R2'
  end

  private

  def r2_enabled?
    ENV['S3_ENABLED'] == 'true'
  end

  def migrate_media_attachments(batch_size)
    Rails.logger.info 'Migrating MediaAttachment files...'

    MediaAttachment.includes(file_attachment: :blob)
                   .where(active_storage_attachments: { name: 'file' })
                   .find_in_batches(batch_size: batch_size) do |batch|
      batch.each do |media|
        next unless media.file.attached?

        migrate_attachment(media.file, "MediaAttachment #{media.id}")
      end
    end
  end

  def migrate_custom_emojis(batch_size)
    Rails.logger.info 'Migrating CustomEmoji files...'

    CustomEmoji.includes(image_attachment: :blob)
               .where(active_storage_attachments: { name: 'image' })
               .find_in_batches(batch_size: batch_size) do |batch|
      batch.each do |emoji|
        next unless emoji.image.attached?

        migrate_attachment(emoji.image, "CustomEmoji #{emoji.id}")
      end
    end
  end

  def migrate_actor_images(batch_size)
    Rails.logger.info 'Migrating Actor avatar and header files...'

    Actor.includes(avatar_attachment: :blob, header_attachment: :blob)
         .find_in_batches(batch_size: batch_size) do |batch|
      batch.each do |actor|
        migrate_attachment(actor.avatar, "Actor #{actor.id} avatar") if actor.avatar.attached?

        migrate_attachment(actor.header, "Actor #{actor.id} header") if actor.header.attached?
      end
    end
  end

  def migrate_attachment(attachment, description)
    return unless should_migrate_attachment?(attachment)

    Rails.logger.info "Migrating #{description}: #{attachment.filename}"

    begin
      perform_migration(attachment, description)
      Rails.logger.info "Successfully migrated #{description}"
    rescue StandardError => e
      Rails.logger.error "Failed to migrate #{description}: #{e.message}"
    end
  end

  def should_migrate_attachment?(attachment)
    attachment.attached? && attachment.service_name.to_s != 'cloudflare_r2'
  end

  def perform_migration(attachment, _description)
    file_content = attachment.download
    r2_blob = create_r2_blob(attachment, file_content)
    attachment.record.send(attachment.name).attach(r2_blob)
  end

  def create_r2_blob(original_attachment, file_content)
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(file_content),
      filename: original_attachment.filename,
      content_type: original_attachment.content_type,
      service_name: 'cloudflare_r2'
    )
  end
end
