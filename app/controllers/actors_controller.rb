# frozen_string_literal: true

class ActorsController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :set_actor
  before_action :ensure_activitypub_request

  # GET /users/:username
  # ActivityPub Actor endpoint
  def show
    render json: @actor.to_activitypub(request),
           content_type: 'application/activity+json; charset=utf-8'
  end

  private

  def set_actor
    username = params[:username]
    @actor = Actor.find_by(username: username, local: true)

    return if @actor

    render json: { error: 'Actor not found' },
           status: :not_found,
           content_type: 'application/activity+json; charset=utf-8'
  end

  def ensure_activitypub_request
    return if activitypub_request?

    # HTML表示にリダイレクト（将来実装）
    redirect_to profile_path(@actor.username)
  end

  def activitypub_request?
    return true if activitypub_content_type?
    return true if activitypub_accept_header?
    return true if activitypub_user_agent?
    return true if activitypub_format?
    return false if html_request?

    # デフォルトではActivityPubとして扱う
    true
  end

  def activitypub_content_type?
    content_type = request.content_type
    return false unless content_type

    content_type.include?('application/activity+json') ||
      content_type.include?('application/ld+json')
  end

  def activitypub_accept_header?
    accept_header = request.headers['Accept'] || ''
    accept_header.include?('application/activity+json') ||
      accept_header.include?('application/ld+json')
  end

  def activitypub_user_agent?
    user_agent = request.headers['User-Agent'] || ''
    %w[ActivityPub Mastodon Pleroma].any? { |agent| user_agent.include?(agent) }
  end

  def activitypub_format?
    %w[json activitypub].include?(params[:format])
  end

  def html_request?
    accept_header = request.headers['Accept'] || ''
    accept_header.include?('text/html')
  end
end
