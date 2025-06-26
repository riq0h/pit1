# frozen_string_literal: true

module Api
  module V2
    class FiltersController < Api::BaseController
      before_action :doorkeeper_authorize!
      before_action :require_user!
      before_action :set_filter, only: %i[show update destroy]

      # GET /api/v2/filters
      def index
        filters = current_user.filters.active.recent
        render json: filters.map { |filter| serialized_filter_v2(filter) }
      end

      # GET /api/v2/filters/:id
      def show
        render json: serialized_filter_v2(@filter)
      end

      # POST /api/v2/filters
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

          render json: serialized_filter_v2(filter)
        else
          render json: { error: 'Validation failed', details: filter.errors.full_messages },
                 status: :unprocessable_entity
        end
      end

      # PUT /api/v2/filters/:id
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

          render json: serialized_filter_v2(@filter)
        else
          render json: { error: 'Validation failed', details: @filter.errors.full_messages },
                 status: :unprocessable_entity
        end
      end

      # DELETE /api/v2/filters/:id
      def destroy
        @filter.destroy
        render json: {}
      end

      private

      def set_filter
        @filter = current_user.filters.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render_not_found('Filter')
      end

      def filter_params
        params.permit(:title, :expires_at, :filter_action)
      end

      def serialized_filter_v2(filter)
        {
          id: filter.id.to_s,
          title: filter.title,
          context: filter.context_array,
          expires_at: filter.expires_at&.iso8601,
          filter_action: filter.filter_action,
          keywords: filter.filter_keywords.map { |keyword| serialized_keyword_v2(keyword) },
          statuses: filter.filter_statuses.map { |status| serialized_filter_status_v2(status) }
        }
      end

      def serialized_keyword_v2(keyword)
        {
          id: keyword.id.to_s,
          keyword: keyword.keyword,
          whole_word: keyword.whole_word
        }
      end

      def serialized_filter_status_v2(filter_status)
        {
          id: filter_status.id.to_s,
          status_id: filter_status.status_id
        }
      end
    end
  end
end
