# frozen_string_literal: true

module Api
  module V1
    class InstanceController < Api::BaseController
      # GET /api/v1/instance
      def show
        render json: instance_info
      end

      private

      def instance_info
        local_domain = Rails.application.config.activitypub.domain
        {
          uri: local_domain,
          title: 'letter',
          short_description: 'General Letter Publication System based on ActivityPub',
          description: 'General Letter Publication System based on ActivityPub',
          email: Rails.application.config.instance_contact_email || '',
          version: '0.1.0 (compatible; letter 0.1.0)',
          urls: {
            streaming_api: "wss://#{local_domain.sub(/^https?:\/\//, '')}"
          },
          stats: {
            user_count: Actor.where(local: true).count,
            status_count: ActivityPubObject.where(object_type: 'Note').count,
            domain_count: Actor.where(local: false).distinct.count(:domain)
          },
          languages: %w[ja en],
          registrations: false,
          approval_required: false,
          invites_enabled: false,
          configuration: {
            accounts: {
              max_featured_tags: 0
            },
            statuses: {
              max_characters: 9999,
              max_media_attachments: 4,
              characters_reserved_per_url: 23
            },
            media_attachments: {
              supported_mime_types: [
                'image/jpeg',
                'image/png',
                'image/gif',
                'image/webp',
                'video/mp4',
                'video/webm'
              ],
              image_size_limit: 52_428_800, # 50MB
              image_matrix_limit: 16_777_216,
              video_size_limit: 524_288_000, # 500MB
              video_frame_rate_limit: 60,
              video_matrix_limit: 2_304_000
            },
            polls: {
              max_options: 4,
              max_characters_per_option: 50,
              min_expiration: 300,
              max_expiration: 2_629_746
            }
          },
          contact_account: nil,
          rules: []
        }
      end
    end
  end
end
