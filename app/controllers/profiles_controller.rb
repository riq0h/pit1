# frozen_string_literal: true

class ProfilesController < ApplicationController
  before_action :find_actor

  def show
    return render_activitypub_profile if activitypub_request?

    @current_tab = params[:tab] || 'posts'
    @posts = load_posts_for_tab(@current_tab)
    setup_pagination

    if params[:max_id].present?
      sleep 0.5
      render partial: 'more_posts'
    end

    # フォロー・フォロワー数
    @followers_count = @actor.followers_count
    @following_count = @actor.following_count
    @posts_count = @actor.posts_count
  end

  private

  def render_activitypub_profile
    render json: @actor.to_activitypub(request),
           content_type: 'application/activity+json; charset=utf-8'
  end

  def load_posts_for_tab(tab)
    case tab
    when 'media'
      load_user_media_posts
    else
      load_user_posts
    end
  end

  def find_actor
    username = params[:username]
    @actor = Actor.find_by(username: username, local: true)

    unless @actor
      render 'errors/not_found', status: :not_found
      return
    end

    # 凍結されたアカウントのチェック
    return unless @actor.suspended?

    render 'errors/suspended', status: :forbidden
    nil
  end

  def load_user_posts
    query = ActivityPubObject
            .joins(:actor)
            .where(actor: @actor)
            .where(visibility: %w[public unlisted])
            .where(object_type: 'Note')
            .where(local: true)
            .includes(:actor)
            .order(published_at: :desc)

    apply_pagination_filters(query).limit(30)
  end

  def load_user_media_posts
    query = ActivityPubObject
            .joins(:actor)
            .joins(:media_attachments)
            .where(actor: @actor)
            .where(visibility: %w[public unlisted])
            .where(object_type: 'Note')
            .where(local: true)
            .includes(:actor, :media_attachments)
            .order(published_at: :desc)
            .distinct

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
    base_query = @current_tab == 'media' ? base_media_query : base_posts_query
    base_query.exists?(['published_at < ?', @posts.last.published_at])
  end

  def base_posts_query
    ActivityPubObject
      .joins(:actor)
      .where(actor: @actor)
      .where(visibility: %w[public unlisted])
      .where(object_type: 'Note')
      .where(local: true)
  end

  def base_media_query
    ActivityPubObject
      .joins(:actor)
      .joins(:media_attachments)
      .where(actor: @actor)
      .where(visibility: %w[public unlisted])
      .where(object_type: 'Note')
      .where(local: true)
      .distinct
  end
end
