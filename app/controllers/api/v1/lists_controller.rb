# frozen_string_literal: true

module Api
  module V1
    class ListsController < Api::BaseController
      before_action :doorkeeper_authorize!
      before_action :require_user!
      before_action :set_list, only: [:show, :update, :destroy, :accounts, :add_accounts, :remove_accounts]

      # GET /api/v1/lists
      def index
        lists = current_user.lists.recent
        render json: lists.map { |list| serialized_list(list) }
      end

      # POST /api/v1/lists
      def create
        list = current_user.lists.build(list_params)
        
        if list.save
          render json: serialized_list(list)
        else
          render json: { error: 'Validation failed', details: list.errors.full_messages }, 
                 status: :unprocessable_entity
        end
      end

      # GET /api/v1/lists/:id
      def show
        render json: serialized_list(@list)
      end

      # PUT /api/v1/lists/:id
      def update
        if @list.update(list_params)
          render json: serialized_list(@list)
        else
          render json: { error: 'Validation failed', details: @list.errors.full_messages }, 
                 status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/lists/:id
      def destroy
        @list.destroy
        render json: {}
      end

      # GET /api/v1/lists/:id/accounts
      def accounts
        limit = [params[:limit].to_i, 40].min
        limit = 20 if limit <= 0
        
        accounts = @list.members.limit(limit)
        render json: accounts.map { |account| serialized_account(account) }
      end

      # POST /api/v1/lists/:id/accounts
      def add_accounts
        account_ids = Array(params[:account_ids])
        
        if account_ids.blank?
          return render json: { error: 'No account IDs provided' }, status: :unprocessable_entity
        end

        accounts = Actor.where(id: account_ids)
        
        accounts.each do |account|
          @list.add_member!(account)
        end

        render json: {}
      end

      # DELETE /api/v1/lists/:id/accounts
      def remove_accounts
        account_ids = Array(params[:account_ids])
        
        if account_ids.blank?
          return render json: { error: 'No account IDs provided' }, status: :unprocessable_entity
        end

        accounts = Actor.where(id: account_ids)
        
        accounts.each do |account|
          @list.remove_member!(account)
        end

        render json: {}
      end

      private

      def set_list
        @list = current_user.lists.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'List not found' }, status: :not_found
      end

      def list_params
        params.permit(:title, :replies_policy, :exclusive)
      end

      def serialized_list(list)
        {
          id: list.id.to_s,
          title: list.title,
          replies_policy: list.replies_policy,
          exclusive: list.exclusive
        }
      end

      def serialized_account(actor)
        {
          id: actor.id.to_s,
          username: actor.username,
          acct: actor.acct,
          display_name: actor.display_name_or_username,
          locked: actor.manually_approves_followers,
          bot: false,
          discoverable: actor.discoverable,
          group: false,
          created_at: actor.created_at&.iso8601,
          note: actor.note || '',
          url: actor.public_url,
          avatar: actor.avatar_url,
          avatar_static: actor.avatar_url,
          header: actor.header_image_url,
          header_static: actor.header_image_url,
          followers_count: actor.followers_count || 0,
          following_count: actor.following_count || 0,
          statuses_count: actor.posts_count || 0,
          last_status_at: nil,
          emojis: [],
          fields: []
        }
      end
    end
  end
end