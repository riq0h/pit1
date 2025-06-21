# frozen_string_literal: true

class ActivitiesController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :set_activity
  before_action :ensure_activitypub_request

  # GET /activities/:id
  # ActivityPub Activity endpoint
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

  def ensure_activitypub_request
    return if activitypub_request?

    redirect_to root_path
  end

  def activitypub_request?
    return true if request.content_type&.include?('application/activity+json')
    return true if request.content_type&.include?('application/ld+json')

    accept_header = request.headers['Accept'] || ''
    return true if accept_header.include?('application/activity+json')
    return true if accept_header.include?('application/ld+json')

    # デフォルトではActivityPubとして扱う
    true
  end

  def build_activity_data(activity)
    base_data = {
      '@context' => 'https://www.w3.org/ns/activitystreams',
      'id' => activity.ap_id,
      'type' => activity.activity_type,
      'actor' => activity.actor.ap_id,
      'published' => activity.published_at.iso8601
    }

    # Activityタイプ別の詳細データ追加
    case activity.activity_type
    when 'Create'
      add_create_activity_data(base_data, activity)
    when 'Follow'
      add_follow_activity_data(base_data, activity)
    when 'Accept', 'Reject'
      add_response_activity_data(base_data, activity)
    when 'Announce'
      add_announce_activity_data(base_data, activity)
    when 'Like'
      add_like_activity_data(base_data, activity)
    when 'Delete'
      add_delete_activity_data(base_data, activity)
    when 'Update'
      add_update_activity_data(base_data, activity)
    when 'Undo'
      add_undo_activity_data(base_data, activity)
    else
      base_data
    end
  end

  def add_create_activity_data(base_data, activity)
    return base_data unless activity.object

    base_data.merge(
      'object' => build_embedded_object(activity.object),
      'to' => build_activity_audience(activity.object, :to),
      'cc' => build_activity_audience(activity.object, :cc)
    )
  end

  def add_follow_activity_data(base_data, activity)
    base_data.merge('object' => activity.target_ap_id)
  end

  def add_response_activity_data(base_data, activity)
    base_data.merge('object' => activity.target_ap_id)
  end

  def add_announce_activity_data(base_data, activity)
    base_data.merge(
      'object' => activity.target_ap_id,
      'to' => ['https://www.w3.org/ns/activitystreams#Public'],
      'cc' => [activity.actor.followers_url]
    )
  end

  def add_like_activity_data(base_data, activity)
    base_data.merge('object' => activity.target_ap_id)
  end

  def add_delete_activity_data(base_data, activity)
    base_data.merge('object' => activity.target_ap_id)
  end

  def add_update_activity_data(base_data, activity)
    return base_data unless activity.object

    base_data.merge(
      'object' => build_updated_object(activity.object),
      'to' => build_activity_audience(activity.object, :to),
      'cc' => build_activity_audience(activity.object, :cc)
    )
  end

  def add_undo_activity_data(base_data, activity)
    base_data.merge('object' => activity.target_ap_id)
  end

  def build_embedded_object(object)
    {
      '@context' => 'https://www.w3.org/ns/activitystreams',
      'id' => object.ap_id,
      'type' => object.object_type,
      'attributedTo' => object.actor.ap_id,
      'content' => object.content,
      'published' => object.published_at.iso8601,
      'url' => object.public_url,
      'to' => build_activity_audience(object, :to),
      'cc' => build_activity_audience(object, :cc),
      'sensitive' => object.sensitive?,
      'summary' => object.summary,
      'inReplyTo' => object.in_reply_to_ap_id
    }.compact
  end

  def build_updated_object(object)
    updated_data = {
      '@context' => 'https://www.w3.org/ns/activitystreams',
      'id' => object.ap_id,
      'type' => object.object_type,
      'attributedTo' => object.actor.ap_id,
      'content' => object.content,
      'published' => object.published_at.iso8601,
      'url' => object.public_url,
      'to' => build_activity_audience(object, :to),
      'cc' => build_activity_audience(object, :cc),
      'sensitive' => object.sensitive?,
      'summary' => object.summary,
      'inReplyTo' => object.in_reply_to_ap_id,
      'attachment' => build_object_attachments(object),
      'tag' => build_object_tags(object)
    }

    # 編集済みの場合はupdatedフィールドを追加
    updated_data['updated'] = object.edited_at.iso8601 if object.edited?

    updated_data.compact
  end

  def build_object_attachments(object)
    object.media_attachments.map do |attachment|
      {
        'type' => 'Document',
        'mediaType' => attachment.content_type,
        'url' => attachment.url,
        'name' => attachment.description || attachment.file_name,
        'width' => attachment.width,
        'height' => attachment.height,
        'blurhash' => attachment.blurhash
      }.compact
    end
  end

  def build_object_tags(object)
    hashtag_tags = object.tags.map do |tag|
      {
        'type' => 'Hashtag',
        'href' => "#{Rails.application.config.activitypub.base_url}/tags/#{tag.name}",
        'name' => "##{tag.name}"
      }
    end

    mention_tags = object.mentions.map do |mention|
      {
        'type' => 'Mention',
        'href' => mention.actor.ap_id,
        'name' => "@#{mention.actor.full_username}"
      }
    end

    hashtag_tags + mention_tags
  end

  def build_activity_audience(object, type)
    case object.visibility
    when 'public'
      build_public_audience(type, object)
    when 'unlisted'
      build_unlisted_audience(type, object)
    when 'private'
      build_followers_audience(type, object)
    when 'direct'
      build_direct_audience(type)
    else
      []
    end
  end

  def build_public_audience(type, object)
    case type
    when :to
      ['https://www.w3.org/ns/activitystreams#Public']
    when :cc
      [object.actor.followers_url]
    end
  end

  def build_unlisted_audience(type, object)
    case type
    when :to
      [object.actor.followers_url]
    when :cc
      ['https://www.w3.org/ns/activitystreams#Public']
    end
  end

  def build_followers_audience(type, object)
    case type
    when :to
      [object.actor.followers_url]
    when :cc
      []
    end
  end
end
