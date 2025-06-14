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
    posts = load_user_post_objects
    reblogs = load_user_reblog_objects
    timeline_items = build_user_timeline_items(posts, reblogs)
    apply_user_timeline_sorting_and_pagination(timeline_items)
  end

  def load_user_post_objects
    ActivityPubObject
      .joins(:actor)
      .where(actor: @actor)
      .where(visibility: %w[public unlisted])
      .where(object_type: 'Note')
      .where(local: true)
      .includes(:actor)
  end

  def load_user_reblog_objects
    Reblog.joins(:actor, :object)
          .where(actor: @actor)
          .where(objects: { visibility: %w[public unlisted] })
          .includes(:actor, object: %i[actor media_attachments])
  end

  def build_user_timeline_items(posts, reblogs)
    timeline_items = []

    posts.find_each do |post|
      timeline_items << build_user_post_timeline_item(post)
    end

    reblogs.find_each do |reblog|
      timeline_items << build_user_reblog_timeline_item(reblog)
    end

    timeline_items
  end

  def build_user_post_timeline_item(post)
    {
      type: :post,
      item: post,
      published_at: post.published_at,
      id: "post_#{post.id}"
    }
  end

  def build_user_reblog_timeline_item(reblog)
    {
      type: :reblog,
      item: reblog,
      published_at: reblog.created_at,
      id: "reblog_#{reblog.id}"
    }
  end

  def apply_user_timeline_sorting_and_pagination(timeline_items)
    timeline_items.sort_by! { |item| -item[:published_at].to_i }
    timeline_items = apply_timeline_pagination_filters(timeline_items)
    timeline_items.take(30)
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

  def apply_timeline_pagination_filters(timeline_items)
    return timeline_items if params[:max_id].blank?

    reference_time = extract_profiles_reference_time_from_max_id
    return timeline_items unless reference_time

    filter_profiles_timeline_items_by_time(timeline_items, reference_time)
  end

  def extract_profiles_reference_time_from_max_id
    max_id = params[:max_id]

    if max_id.start_with?('post_')
      extract_profiles_post_reference_time(max_id)
    elsif max_id.start_with?('reblog_')
      extract_profiles_reblog_reference_time(max_id)
    end
  end

  def extract_profiles_post_reference_time(max_id)
    post_id = max_id.sub('post_', '')
    reference_post = ActivityPubObject.find_by(id: post_id)
    reference_post&.published_at
  end

  def extract_profiles_reblog_reference_time(max_id)
    reblog_id = max_id.sub('reblog_', '')
    reference_reblog = Reblog.find_by(id: reblog_id)
    reference_reblog&.created_at
  end

  def filter_profiles_timeline_items_by_time(timeline_items, reference_time)
    timeline_items.select { |item| item[:published_at] < reference_time }
  end

  def find_post_by_id(id)
    ActivityPubObject.find_by(id: id)
  end

  def get_post_display_id(timeline_item)
    if timeline_item.is_a?(Hash)
      timeline_item[:id]
    else
      # 後方互換性のため
      timeline_item.id
    end
  end

  def setup_pagination
    return unless @posts.any?

    @older_max_id = get_post_display_id(@posts.last) if @posts.last
    @more_posts_available = check_older_posts_available
  end

  def check_older_posts_available
    return false unless @posts.any?

    if @current_tab == 'media'
      base_query = base_media_query
      base_query.exists?(['published_at < ?', @posts.last.published_at])
    else
      # タイムライン形式の場合
      last_item_time = @posts.last[:published_at]

      # より古い投稿またはリポストがあるかチェック
      older_posts_exist = base_posts_query.exists?(['published_at < ?', last_item_time])
      older_reblogs_exist = Reblog.joins(:actor, :object)
                                  .where(actor: @actor)
                                  .where(objects: { visibility: %w[public unlisted] })
                                  .exists?(['reblogs.created_at < ?', last_item_time])

      older_posts_exist || older_reblogs_exist
    end
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
