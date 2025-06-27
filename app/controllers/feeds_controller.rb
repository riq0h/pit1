# frozen_string_literal: true

class FeedsController < ApplicationController
  before_action :set_cache_headers

  # ユーザ個別のRSSフィード
  def user
    @actor = Actor.local.find_by!(username: params[:username])
    @posts = @actor.objects
                   .where(object_type: 'Note')
                   .where.not(published_at: nil)
                   .includes(:actor, :media_attachments)
                   .order(published_at: :desc)
                   .limit(20)

    respond_to do |format|
      format.rss { render layout: false }
    end
  end

  # ローカルタイムラインのAtomフィード
  def local
    @posts = ActivityPubObject.joins(:actor)
                              .where(actors: { domain: nil })
                              .where(object_type: 'Note')
                              .where.not(published_at: nil)
                              .includes(:actor, :media_attachments)
                              .order(published_at: :desc)
                              .limit(50)

    respond_to do |format|
      format.atom { render layout: false }
    end
  end

  private

  def set_cache_headers
    response.headers['Cache-Control'] = 'public, max-age=300'
  end
end
