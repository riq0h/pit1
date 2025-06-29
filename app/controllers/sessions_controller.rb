# frozen_string_literal: true

class SessionsController < ApplicationController
  before_action :redirect_if_signed_in, only: %i[new create]

  # GET /login
  def new
    # ログインフォーム表示
  end

  # POST /login
  def create
    Rails.logger.info "🔍 Login attempt for username: #{params[:username]}"
    actor = find_local_actor

    if actor
      Rails.logger.info "🔍 Found actor: #{actor.username}"
      auth_result = actor.authenticate(params[:password])
      Rails.logger.info "🔍 Authentication result: #{auth_result.inspect}"

      if auth_result
        login_success(actor)
      else
        Rails.logger.info "🔍 Authentication failed for #{actor.username}"
        login_failure
      end
    else
      Rails.logger.info "🔍 Actor not found for username: #{params[:username]}"
      login_failure
    end
  end

  # DELETE /logout
  def destroy
    logout_user
    redirect_to root_path, notice: I18n.t('auth.logged_out')
  end

  private

  def find_local_actor
    username = params[:username]&.strip
    return nil if username.blank?

    Actor.local.where('LOWER(username) = LOWER(?)', username).first
  end

  def login_success(actor)
    login_user(actor)
    redirect_to_after_login
  end

  def login_failure
    flash.now[:alert] = I18n.t('auth.invalid_credentials')
    render :new, status: :unprocessable_entity
  end

  def login_user(actor)
    session[:current_user_id] = actor.id
    session[:logged_in_at] = Time.current
    Rails.logger.info "🔐 User #{actor.username} logged in"
  end

  def logout_user
    user_id = session[:current_user_id]
    session.delete(:current_user_id)
    session.delete(:logged_in_at)
    Rails.logger.info "🔓 User #{user_id} logged out"
  end

  def redirect_to_after_login
    redirect_url = session.delete(:return_to) || config_path
    redirect_to redirect_url, notice: I18n.t('auth.logged_in')
  end

  def redirect_if_signed_in
    redirect_to config_path if user_signed_in?
  end
end
