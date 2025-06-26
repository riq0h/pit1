# frozen_string_literal: true

class ActivitiesController < ApplicationController
  include ActivityPubRequestHandling
  include ActivityPubObjectBuilding
  include ActivityDataBuilder

  skip_before_action :verify_authenticity_token
  before_action :set_activity
  before_action :ensure_activitypub_request

  # GET /activities/:id
  # ActivityPubアクティビティエンドポイント
  def show
    render json: build_activity_data(@activity),
           content_type: 'application/activity+json; charset=utf-8'
  end

  private

  def set_activity
    # IDからアクティビティを検索
    @activity = find_activity_by_id(params[:id])

    return if @activity

    render json: { error: 'Activity not found' },
           status: :not_found,
           content_type: 'application/activity+json; charset=utf-8'
  end

  def find_activity_by_id(id)
    # フルap_idでの検索
    activity = Activity.find_by(ap_id: id)
    return activity if activity

    # IDでの直接検索
    Activity.find_by(id: id)
  end
end
