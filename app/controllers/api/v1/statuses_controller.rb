# frozen_string_literal: true

module Api
  module V1
    class StatusesController < Api::BaseController
      include AccountSerializer
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
          create_activity_for_status
          render json: serialized_status(@status), status: :created
        else
          render_validation_error(@status)
        end
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

        # TODO: Implement favouriting
        render json: serialized_status(@status)
      end

      # POST /api/v1/statuses/:id/unfavourite
      def unfavourite
        return render json: { error: 'This action requires authentication' }, status: :unauthorized unless current_user

        # TODO: Implement unfavouriting
        render json: serialized_status(@status)
      end

      # POST /api/v1/statuses/:id/reblog
      def reblog
        return render json: { error: 'This action requires authentication' }, status: :unauthorized unless current_user
        return render json: { error: 'Cannot reblog own status' }, status: :unprocessable_content if @status.actor == current_user

        # TODO: Implement reblogging (Announce activity)
        render json: serialized_status(@status)
      end

      # POST /api/v1/statuses/:id/unreblog
      def unreblog
        return render json: { error: 'This action requires authentication' }, status: :unauthorized unless current_user

        # TODO: Implement unreblogging
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
        permitted_params = params.permit(:status, :in_reply_to_id, :sensitive, :spoiler_text, :visibility, :language)

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

        transformed_params
      end

      def serialized_status(status)
        {
          id: status.id.to_s,
          created_at: status.published_at.iso8601,
          in_reply_to_id: in_reply_to_id(status),
          in_reply_to_account_id: in_reply_to_account_id(status),
          sensitive: status.sensitive || false,
          spoiler_text: status.summary || '',
          visibility: status.visibility || 'public',
          language: 'ja',
          uri: status.ap_id,
          url: status.public_url,
          replies_count: replies_count(status),
          reblogs_count: 0, # TODO: Implement
          favourites_count: 0, # TODO: Implement
          content: status.content || '',
          reblog: nil,
          account: serialized_account(status.actor),
          media_attachments: [], # TODO: Implement
          mentions: [], # TODO: Implement
          tags: [], # TODO: Implement
          emojis: [],
          card: nil,
          poll: nil
        }
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

      def generate_status_ap_id
        Time.current.to_i
        random_id = SecureRandom.hex(3) # 6桁
        domain = Rails.application.config.activitypub.domain
        scheme = Rails.env.production? ? 'https' : 'http'

        "#{scheme}://#{domain}/@#{current_user.username}/#{random_id}"
      end

      def generate_activity_ap_id(status)
        "#{status.ap_id}#activity"
      end

      def generate_delete_activity_ap_id(status)
        "#{status.ap_id}#delete-#{Time.current.to_i}"
      end
    end
  end
end
