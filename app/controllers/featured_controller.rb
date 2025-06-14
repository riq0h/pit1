# frozen_string_literal: true

class FeaturedController < ApplicationController
  def show
    username = params[:username]
    @actor = Actor.find_by(username: username, local: true)

    unless @actor
      render json: { error: 'Actor not found' }, status: :not_found
      return
    end

    # Featured collection (currently empty - can be extended later)
    featured_collection = {
      '@context' => 'https://www.w3.org/ns/activitystreams',
      'id' => "#{activitypub_base_url}/users/#{@actor.username}/collections/featured",
      'type' => 'OrderedCollection',
      'totalItems' => 0,
      'orderedItems' => []
    }

    render json: featured_collection, content_type: 'application/activity+json; charset=utf-8'
  end
end
