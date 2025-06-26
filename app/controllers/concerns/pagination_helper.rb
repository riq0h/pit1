# frozen_string_literal: true

module PaginationHelper
  extend ActiveSupport::Concern

  private

  # max_idベースのページネーション設定
  def setup_max_id_pagination
    return unless @posts.any?

    @older_max_id = get_post_display_id(@posts.last) if @posts.last
    @more_posts_available = check_older_posts_available
  end

  # offsetベースのページネーション設定
  def setup_offset_pagination(per_page = 30)
    @next_offset = params[:offset].to_i + per_page
    @more_posts_available = @posts.count == per_page
  end
end
