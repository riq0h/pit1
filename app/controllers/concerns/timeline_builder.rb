# frozen_string_literal: true

module TimelineBuilder
  extend ActiveSupport::Concern

  private

  def setup_pagination
    setup_max_id_pagination
  end

  def apply_pagination_filters(query)
    if params[:max_id].present?
      reference_post = find_post_by_id(params[:max_id])
      query = query.where(published_at: ...reference_post.published_at) if reference_post
    end
    query
  end

  def build_post_timeline_item(post)
    {
      type: :post,
      item: post,
      published_at: post.published_at,
      id: "post_#{post.id}"
    }
  end

  def build_reblog_timeline_item(reblog)
    {
      type: :reblog,
      item: reblog,
      published_at: reblog.created_at,
      id: "reblog_#{reblog.id}"
    }
  end

  def build_pinned_timeline_item(post)
    {
      type: :pinned_post,
      item: post,
      published_at: post.published_at,
      id: "pinned_#{post.id}"
    }
  end

  def build_timeline_items_from_posts_and_reblogs(posts, reblogs)
    timeline_items = posts.map do |post|
      build_post_timeline_item(post)
    end

    reblogs.each do |reblog|
      timeline_items << build_reblog_timeline_item(reblog)
    end

    timeline_items
  end
end
