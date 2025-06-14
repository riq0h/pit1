# frozen_string_literal: true

class FollowersController < ApplicationController
  skip_before_action :verify_authenticity_token

  def show
    username = params[:username]
    @actor = Actor.find_by(username: username, local: true)

    unless @actor
      render json: { error: 'Actor not found' }, status: :not_found
      return
    end

    followers_collection = {
      '@context' => 'https://www.w3.org/ns/activitystreams',
      'id' => "#{activitypub_base_url}/users/#{@actor.username}/followers",
      'type' => 'OrderedCollection',
      'totalItems' => @actor.followers_count,
      'orderedItems' => [] # プライバシー保護のため詳細は非表示
    }

    render json: followers_collection, content_type: 'application/activity+json; charset=utf-8'
  end
end
