# frozen_string_literal: true

class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  protect_from_forgery with: :exception, unless: :activitypub_request?
  before_action :set_current_user
  before_action :set_locale

  private

  def activitypub_request?
    request.content_type == 'application/activity+json' ||
      request.content_type == 'application/ld+json' ||
      request.headers['Accept']&.include?('application/activity+json') ||
      request.headers['Accept']&.include?('application/ld+json')
  end

  def set_current_user
    @current_user = User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def set_locale
    I18n.locale = extract_locale || I18n.default_locale
  end

  def extract_locale
    parsed_locale = request.env['HTTP_ACCEPT_LANGUAGE']&.scan(/^[a-z]{2}/)&.first
    I18n.available_locales.map(&:to_s).include?(parsed_locale) ? parsed_locale : nil
  end

  def require_admin
    redirect_to root_path unless @current_user&.admin?
  end

  def activitypub_content_type
    'application/activity+json; charset=utf-8'
  end
end
