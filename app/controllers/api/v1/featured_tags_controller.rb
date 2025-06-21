# frozen_string_literal: true

module Api
  module V1
    class FeaturedTagsController < Api::BaseController
      before_action :doorkeeper_authorize!
      before_action :require_user!
      before_action :set_featured_tag, only: [:destroy]

      # GET /api/v1/featured_tags
      def index
        featured_tags = current_user.featured_tags.includes(:tag).recent
        render json: featured_tags.map { |featured_tag| serialized_featured_tag(featured_tag) }
      end

      # POST /api/v1/featured_tags
      def create
        tag_name = params[:name].to_s.strip.downcase
        return render json: { error: 'Tag name is required' }, status: :unprocessable_entity if tag_name.blank?

        # タグを作成または取得
        tag = Tag.find_or_create_by(name: tag_name)

        # 既にfeaturedされているかチェック
        existing_featured_tag = current_user.featured_tags.find_by(tag: tag)
        return render json: serialized_featured_tag(existing_featured_tag) if existing_featured_tag

        # Featured tagを作成
        featured_tag = current_user.featured_tags.build(tag: tag)

        if featured_tag.save
          # 既存の投稿でこのタグを使っている数をカウント
          update_featured_tag_count(featured_tag)
          render json: serialized_featured_tag(featured_tag)
        else
          render json: { error: 'Failed to create featured tag' }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/featured_tags/:id
      def destroy
        @featured_tag.destroy
        render json: {}
      end

      # GET /api/v1/featured_tags/suggestions
      def suggestions
        # 最近使用したタグから最大10個を提案
        recent_tags = Tag.joins(:object_tags)
                         .joins('JOIN objects ON object_tags.object_id = objects.id')
                         .where(objects: { actor: current_user })
                         .where.not(id: current_user.featured_tags.select(:tag_id))
                         .group('tags.id')
                         .order('MAX(object_tags.created_at) DESC')
                         .limit(10)

        render json: recent_tags.map { |tag| serialized_tag(tag) }
      end

      private

      def set_featured_tag
        @featured_tag = current_user.featured_tags.find(params[:id])
      end

      def serialized_featured_tag(featured_tag)
        {
          id: featured_tag.id.to_s,
          name: featured_tag.name,
          statuses_count: featured_tag.statuses_count,
          last_status_at: featured_tag.last_status_at&.iso8601
        }
      end

      def serialized_tag(tag)
        {
          name: tag.name,
          url: "#{request.base_url}/tags/#{tag.name}",
          history: []
        }
      end

      def update_featured_tag_count(featured_tag)
        # ユーザの投稿でこのタグが使われている数をカウント
        count = current_user.objects
                            .joins(:object_tags)
                            .where(object_tags: { tag: featured_tag.tag })
                            .count

        last_status = current_user.objects
                                  .joins(:object_tags)
                                  .where(object_tags: { tag: featured_tag.tag })
                                  .order(published_at: :desc)
                                  .first

        featured_tag.update!(
          statuses_count: count,
          last_status_at: last_status&.published_at
        )
      end
    end
  end
end
