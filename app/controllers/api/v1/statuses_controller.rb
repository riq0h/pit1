# frozen_string_literal: true

module Api
  module V1
    class StatusesController < Api::BaseController
      include AccountSerializer
      include StatusSerializer
      include MediaSerializer
      include MentionTagSerializer
      before_action :doorkeeper_authorize!, except: [:show]
      before_action :doorkeeper_authorize!, only: [:show], if: -> { request.authorization.present? }
      before_action :set_status, except: [:create]

      # GET /api/v1/statuses/:id
      def show
        render json: serialized_status(@status)
      end

      # POST /api/v1/statuses
      def create
        return render json: { error: 'This action requires authentication' }, status: :unauthorized unless current_user

        @status = build_status_object

        if @status.save
          attach_media_to_status if @media_ids&.any?
          create_activity_for_status
          render json: serialized_status(@status), status: :created
        else
          render_validation_error(@status)
        end
      end

      # POST /api/v1/statuses/:id/favourite
      def favourite
        return render json: { error: 'This action requires authentication' }, status: :unauthorized unless current_user

        favourite = current_user.favourites.find_or_create_by(object: @status)

        if favourite.persisted?
          create_like_activity(@status)
          render json: serialized_status(@status)
        else
          render json: { error: 'Failed to favourite status' }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/statuses/:id/unfavourite
      def unfavourite
        return render json: { error: 'This action requires authentication' }, status: :unauthorized unless current_user

        favourite = current_user.favourites.find_by(object: @status)

        if favourite
          create_undo_like_activity(@status, favourite)
          favourite.destroy
        end

        render json: serialized_status(@status)
      end

      # POST /api/v1/statuses/:id/reblog
      def reblog
        return render json: { error: 'This action requires authentication' }, status: :unauthorized unless current_user
        return render json: { error: 'Cannot reblog own status' }, status: :unprocessable_content if @status.actor == current_user

        reblog = current_user.reblogs.find_or_create_by(object: @status)

        if reblog.persisted?
          create_announce_activity(@status)
          render json: serialized_status(@status)
        else
          render json: { error: 'Failed to reblog status' }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/statuses/:id/unreblog
      def unreblog
        return render json: { error: 'This action requires authentication' }, status: :unauthorized unless current_user

        reblog = current_user.reblogs.find_by(object: @status)

        if reblog
          create_undo_announce_activity(@status, reblog)
          reblog.destroy
        end

        render json: serialized_status(@status)
      end

      # PUT /api/v1/statuses/:id
      def update
        return render json: { error: 'This action requires authentication' }, status: :unauthorized unless current_user
        return render json: { error: 'Not authorized' }, status: :forbidden unless @status.actor == current_user

        if @status.update(status_params)
          render json: serialized_status(@status)
        else
          render json: { error: 'Validation failed', details: @status.errors.full_messages },
                 status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/statuses/:id
      def destroy
        return render json: { error: 'This action requires authentication' }, status: :unauthorized unless current_user
        return render json: { error: 'Not authorized' }, status: :forbidden unless @status.actor == current_user

        # Create Delete activity
        current_user.activities.create!(
          ap_id: generate_delete_activity_ap_id(@status),
          activity_type: 'Delete',
          target_ap_id: @status.ap_id,
          published_at: Time.current,
          local: true,
          processed: true
        )

        @status.destroy
        render json: serialized_status(@status)
      end

      # GET /api/v1/statuses/:id/context
      def context
        # TODO: Implement conversation context (replies, ancestors)
        render json: {
          ancestors: [],
          descendants: []
        }
      end

      private

      def build_status_object
        current_user.objects.build(status_creation_params)
      end

      def status_creation_params
        status_params.merge(
          object_type: 'Note',
          published_at: Time.current,
          local: true,
          ap_id: generate_status_ap_id
        )
      end

      def create_activity_for_status
        current_user.activities.create!(
          ap_id: generate_activity_ap_id(@status),
          activity_type: 'Create',
          object: @status,
          published_at: Time.current,
          local: true,
          processed: true
        )
      end

      def attach_media_to_status
        media_attachments = current_user.media_attachments.where(id: @media_ids, object_id: nil)
        media_attachments.update_all(object_id: @status.id)
      end

      def render_validation_error(object)
        render json: {
          error: 'Validation failed',
          details: object.errors.full_messages
        }, status: :unprocessable_entity
      end

      # PUT /api/v1/statuses/:id
      def update
        return render json: { error: 'This action requires authentication' }, status: :unauthorized unless current_user
        return render json: { error: 'Not authorized' }, status: :forbidden unless @status.actor == current_user

        if @status.update(status_params)
          render json: serialized_status(@status)
        else
          render json: { error: 'Validation failed', details: @status.errors.full_messages },
                 status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/statuses/:id
      def destroy
        return render json: { error: 'This action requires authentication' }, status: :unauthorized unless current_user
        return render json: { error: 'Not authorized' }, status: :forbidden unless @status.actor == current_user

        # Create Delete activity
        current_user.activities.create!(
          ap_id: generate_delete_activity_ap_id(@status),
          activity_type: 'Delete',
          target_ap_id: @status.ap_id,
          published_at: Time.current,
          local: true,
          processed: true
        )

        @status.destroy
        render json: serialized_status(@status)
      end

      # POST /api/v1/statuses/:id/favourite
      def favourite
        return render json: { error: 'This action requires authentication' }, status: :unauthorized unless current_user

        favourite = current_user.favourites.find_or_create_by(object: @status)

        if favourite.persisted?
          create_like_activity(@status)
          render json: serialized_status(@status)
        else
          render json: { error: 'Failed to favourite status' }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/statuses/:id/unfavourite
      def unfavourite
        return render json: { error: 'This action requires authentication' }, status: :unauthorized unless current_user

        favourite = current_user.favourites.find_by(object: @status)

        if favourite
          create_undo_like_activity(@status, favourite)
          favourite.destroy
        end

        render json: serialized_status(@status)
      end

      # POST /api/v1/statuses/:id/reblog
      def reblog
        return render json: { error: 'This action requires authentication' }, status: :unauthorized unless current_user
        return render json: { error: 'Cannot reblog own status' }, status: :unprocessable_content if @status.actor == current_user

        reblog = current_user.reblogs.find_or_create_by(object: @status)

        if reblog.persisted?
          create_announce_activity(@status)
          render json: serialized_status(@status)
        else
          render json: { error: 'Failed to reblog status' }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/statuses/:id/unreblog
      def unreblog
        return render json: { error: 'This action requires authentication' }, status: :unauthorized unless current_user

        reblog = current_user.reblogs.find_by(object: @status)

        if reblog
          create_undo_announce_activity(@status, reblog)
          reblog.destroy
        end

        render json: serialized_status(@status)
      end

      # GET /api/v1/statuses/:id/context
      def context
        # TODO: Implement conversation context (replies, ancestors)
        render json: {
          ancestors: [],
          descendants: []
        }
      end

      def set_status
        @status = ActivityPubObject.where(object_type: 'Note')
                                   .where(local: true)
                                   .find(params[:id])
      end

      def status_params
        permitted_params = params.permit(:status, :in_reply_to_id, :sensitive, :spoiler_text, :visibility, :language, media_ids: [])

        transformed_params = permitted_params.transform_keys do |key|
          case key
          when 'status' then 'content'
          when 'spoiler_text' then 'summary'
          when 'in_reply_to_id' then 'in_reply_to_ap_id'
          else key
          end
        end

        # Convert in_reply_to_id to ActivityPub ID
        if transformed_params['in_reply_to_ap_id'].present?
          in_reply_to = ActivityPubObject.find_by(id: transformed_params['in_reply_to_ap_id'])
          transformed_params['in_reply_to_ap_id'] = in_reply_to&.ap_id
        end

        # Set default visibility
        transformed_params['visibility'] ||= 'public'

        # Remove media_ids from transformed_params as it's handled separately
        @media_ids = transformed_params.delete('media_ids')

        transformed_params
      end

      def serialized_status(status)
        base_status_data(status).merge(
          interaction_data(status),
          content_data(status),
          metadata_data(status)
        )
      end

      def in_reply_to_id(status)
        return nil if status.in_reply_to_ap_id.blank?

        in_reply_to = ActivityPubObject.find_by(ap_id: status.in_reply_to_ap_id)
        in_reply_to&.id&.to_s
      end

      def in_reply_to_account_id(status)
        return nil if status.in_reply_to_ap_id.blank?

        in_reply_to = ActivityPubObject.find_by(ap_id: status.in_reply_to_ap_id)
        return nil unless in_reply_to&.actor

        in_reply_to.actor.id.to_s
      end

      def replies_count(status)
        ActivityPubObject.where(in_reply_to_ap_id: status.ap_id).count
      end

      def favourited_by_current_user?(status)
        return false unless current_user

        current_user.favourites.exists?(object: status)
      end

      def reblogged_by_current_user?(status)
        return false unless current_user

        current_user.reblogs.exists?(object: status)
      end

      def generate_activity_ap_id(status)
        "#{status.ap_id}#activity"
      end

      def generate_delete_activity_ap_id(status)
        "#{status.ap_id}#delete-#{Time.current.to_i}"
      end

      def create_like_activity(status)
        like_activity = current_user.activities.create!(
          ap_id: generate_like_activity_ap_id(status),
          activity_type: 'Like',
          object: status,
          published_at: Time.current,
          local: true,
          processed: true
        )

        # Queue for federation delivery to the status owner
        return unless status.actor != current_user && !status.actor.local?

        SendActivityJob.perform_later(like_activity.id, [status.actor.inbox_url])
      end

      def create_undo_like_activity(status, _favourite)
        undo_activity = current_user.activities.create!(
          ap_id: generate_undo_like_activity_ap_id(status),
          activity_type: 'Undo',
          target_ap_id: generate_like_activity_ap_id(status),
          published_at: Time.current,
          local: true,
          processed: true
        )

        # Queue for federation delivery to the status owner
        return unless status.actor != current_user && !status.actor.local?

        SendActivityJob.perform_later(undo_activity.id, [status.actor.inbox_url])
      end

      def generate_like_activity_ap_id(status)
        "#{status.ap_id}#like-#{current_user.id}-#{Time.current.to_i}"
      end

      def generate_undo_like_activity_ap_id(status)
        "#{status.ap_id}#undo-like-#{current_user.id}-#{Time.current.to_i}"
      end

      def create_announce_activity(status)
        announce_activity = build_announce_activity(status)
        deliver_announce_activity(announce_activity, status)
      end

      def build_announce_activity(status)
        current_user.activities.create!(
          ap_id: generate_announce_activity_ap_id(status),
          activity_type: 'Announce',
          object: status,
          published_at: Time.current,
          local: true,
          processed: true
        )
      end

      def deliver_announce_activity(announce_activity, status)
        target_inboxes = collect_announce_target_inboxes(status)
        return unless target_inboxes.any?

        SendActivityJob.perform_later(announce_activity.id, target_inboxes.uniq)
      end

      def collect_announce_target_inboxes(status)
        target_inboxes = []

        # Add status owner's inbox
        target_inboxes << status.actor.inbox_url if status.actor != current_user && !status.actor.local?

        # Add follower inboxes for public announces
        if status.visibility == 'public'
          follower_inboxes = current_user.followers.where(local: false).pluck(:inbox_url)
          target_inboxes.concat(follower_inboxes)
        end

        target_inboxes
      end

      def create_undo_announce_activity(status, _reblog)
        undo_activity = build_undo_announce_activity(status)
        deliver_undo_announce_activity(undo_activity, status)
      end

      def build_undo_announce_activity(status)
        current_user.activities.create!(
          ap_id: generate_undo_announce_activity_ap_id(status),
          activity_type: 'Undo',
          target_ap_id: generate_announce_activity_ap_id(status),
          published_at: Time.current,
          local: true,
          processed: true
        )
      end

      def deliver_undo_announce_activity(undo_activity, status)
        target_inboxes = collect_announce_target_inboxes(status)
        return unless target_inboxes.any?

        SendActivityJob.perform_later(undo_activity.id, target_inboxes.uniq)
      end

      def generate_announce_activity_ap_id(status)
        "#{status.ap_id}#announce-#{current_user.id}-#{Time.current.to_i}"
      end

      def generate_undo_announce_activity_ap_id(status)
        "#{status.ap_id}#undo-announce-#{current_user.id}-#{Time.current.to_i}"
      end
    end
  end
end
