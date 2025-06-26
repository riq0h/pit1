# frozen_string_literal: true

class ActorsController < ApplicationController
  include ErrorResponseHelper
  include ActivityPubBlockerControl
  include ActivityPubRequestHandling

  skip_before_action :verify_authenticity_token
  before_action :set_actor
  before_action :ensure_activitypub_request
  before_action :check_if_blocked_by_target, if: -> { activitypub_request? }

  # GET /users/:username
  # ActivityPubアクターエンドポイント
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
    super(status: :moved_permanently)
  end
end
