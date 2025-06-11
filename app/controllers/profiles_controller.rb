# frozen_string_literal: true

class ProfilesController < ApplicationController
  before_action :find_actor

  def show
    # 投稿一覧を取得（公開投稿のみ）
    @posts = load_user_posts

    # フォロー・フォロワー数
    @followers_count = @actor.followers_count
    @following_count = @actor.following_count
    @posts_count = @actor.posts_count
  end

  private

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
    ActivityPubObject
      .joins(:actor)
      .where(actor: @actor)
      .where(visibility: %w[public unlisted])
      .where(object_type: 'Note')
      .includes(:actor)
      .order(published_at: :desc)
      .limit(30)
  end
end
