# frozen_string_literal: true

module Api
  module V1
    class FiltersController < Api::BaseController
      before_action :doorkeeper_authorize!
      before_action :require_user!
      before_action :set_filter, only: %i[show update destroy]

      # GET /api/v1/filters
      def index
        filters = current_user.filters.active.recent
        render json: filters.map { |filter| serialized_filter(filter) }
      end

      # GET /api/v1/filters/:id
      def show
        render json: serialized_filter(@filter)
      end

      # POST /api/v1/filters
      def create
        filter = current_user.filters.build(filter_params)
        filter.context_array = params[:context] if params[:context].present?

        if filter.save
          # キーワードを追加
          if params[:keywords_attributes].present?
            params[:keywords_attributes].each do |keyword_params|
              filter.add_keyword!(keyword_params[:keyword], whole_word: keyword_params[:whole_word] == 'true')
            end
          end

          render json: serialized_filter(filter)
        else
          render json: { error: 'Validation failed', details: filter.errors.full_messages },
                 status: :unprocessable_entity
        end
      end

      # PUT /api/v1/filters/:id
      def update
        if @filter.update(filter_params)
          @filter.context_array = params[:context] if params[:context].present?
          @filter.save if @filter.context_changed?

          # キーワードを更新
          if params[:keywords_attributes].present?
            @filter.filter_keywords.destroy_all
            params[:keywords_attributes].each do |keyword_params|
              @filter.add_keyword!(keyword_params[:keyword], whole_word: keyword_params[:whole_word] == 'true')
            end
          end

          render json: serialized_filter(@filter)
        else
          render json: { error: 'Validation failed', details: @filter.errors.full_messages },
                 status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/filters/:id
      def destroy
        @filter.destroy
        render json: {}
      end

      private

      def set_filter
        @filter = current_user.filters.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Filter not found' }, status: :not_found
      end

      def filter_params
        params.permit(:title, :expires_at, :filter_action)
      end

      def serialized_filter(filter)
        {
          id: filter.id.to_s,
          title: filter.title,
          context: filter.context_array,
          expires_at: filter.expires_at&.iso8601,
          filter_action: filter.filter_action,
          keywords: filter.filter_keywords.map { |keyword| serialized_keyword(keyword) },
          statuses: filter.filter_statuses.map { |status| serialized_filter_status(status) }
        }
      end

      def serialized_keyword(keyword)
        {
          id: keyword.id.to_s,
          keyword: keyword.keyword,
          whole_word: keyword.whole_word
        }
      end

      def serialized_filter_status(filter_status)
        {
          id: filter_status.id.to_s,
          status_id: filter_status.status_id
        }
      end
    end
  end
end
