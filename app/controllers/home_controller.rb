# frozen_string_literal: true

class HomeController < ApplicationController
  def index
    @posts = load_public_timeline
    @page_title = I18n.t('pages.home.title')

    setup_pagination

    return if params[:max_id].blank?

    sleep 0.5
    render partial: 'more_posts'
  end

  private

  def load_public_timeline
    query = ActivityPubObject.joins(:actor)
                             .where(actors: { local: true })
                             .where(visibility: %w[public unlisted])
                             .where(local: true)
                             .includes(:actor, :media_attachments)
                             .order(published_at: :desc)

    apply_pagination_filters(query).limit(30)
  end

  def apply_pagination_filters(query)
    if params[:max_id].present?
      reference_post = find_post_by_id(params[:max_id])
      query = query.where(published_at: ...reference_post.published_at) if reference_post
    end
    query
  end

  def find_post_by_id(id)
    ActivityPubObject.find_by(id: id)
  end

  def get_post_display_id(post)
    post.id
  end

  def setup_pagination
    return unless @posts.any?

    @older_max_id = get_post_display_id(@posts.last) if @posts.last
    @more_posts_available = check_older_posts_available
  end

  def check_older_posts_available
    base_query.exists?(['published_at < ?', @posts.last.published_at])
  end

  def base_query
    ActivityPubObject.joins(:actor)
                     .where(actors: { local: true })
                     .where(visibility: %w[public unlisted])
                     .where(local: true)
  end
end
