# frozen_string_literal: true

class PostsController < ApplicationController
  before_action :set_post, only: [:show_html]

  # GET /@{username}/{id}
  # HTML表示用
  def show_html
    @actor = @post.actor
    @media_attachments = @post.media_attachments.includes(:actor)

    setup_meta_tags
  end

  private

  def setup_meta_tags
    title = truncate(@post.content_plaintext, length: 60)
    description = truncate(@post.content_plaintext, length: 160)

    configure_meta_tags(title, description)
  end

  def configure_meta_tags(title, description)
    image_url = @post.media_attachments.first&.file_url || @actor.avatar_url

    @meta_tags = {
      title: title,
      description: description,
      og: build_og_tags(description, image_url),
      twitter: build_twitter_tags(description, image_url)
    }
  end

  def build_og_tags(description, image_url)
    {
      title: "#{@actor.display_name} (@#{@actor.username})",
      description: description,
      type: 'article',
      url: @post.public_url,
      image: image_url
    }
  end

  def build_twitter_tags(description, image_url)
    {
      card: @post.media_attachments.any? ? 'summary_large_image' : 'summary',
      title: "#{@actor.display_name} (@#{@actor.username})",
      description: description,
      image: image_url
    }
  end

  def set_post
    username = params[:username]
    id_param = params[:id]

    actor = find_actor(username)
    return unless actor

    @post = find_post(actor, id_param)
    render_not_found unless @post
  end

  def find_actor(username)
    actor = Actor.local.find_by(username: username)
    render_not_found unless actor
    actor
  end

  def find_post(actor, id_param)
    Object.joins(:actor)
          .where(actors: { id: actor.id })
          .where('objects.ap_id LIKE ?', "%/objects/#{id_param}")
          .first
  end

  def render_not_found
    render file: Rails.public_path.join('404.html'), status: :not_found
  end

  attr_writer :meta_tags

  def truncate(text, options = {})
    return '' if text.blank?

    length = options[:length] || 30
    text.length > length ? "#{text[0...length]}..." : text
  end
end
