# frozen_string_literal: true

module Api
  module V1
    module Admin
      class AccountsController < Api::BaseController
        before_action :doorkeeper_authorize!
        before_action :require_admin!
        before_action :set_account, except: [:index]

        # GET /api/v1/admin/accounts
        def index
          accounts = Actor.includes(:web_push_subscriptions)
                          .order(created_at: :desc)
                          .limit(params[:limit]&.to_i || 40)

          if params[:local] == 'true'
            accounts = accounts.local
          elsif params[:remote] == 'true'
            accounts = accounts.remote
          end

          render json: accounts.map { |account| admin_account_json(account) }
        end

        # GET /api/v1/admin/accounts/:id
        def show
          render json: admin_account_json(@account)
        end

        # POST /api/v1/admin/accounts/:id/enable
        def enable
          @account.update!(suspended: false)
          render json: admin_account_json(@account)
        end

        # POST /api/v1/admin/accounts/:id/suspend
        def suspend
          @account.update!(suspended: true)
          render json: admin_account_json(@account)
        end

        # DELETE /api/v1/admin/accounts/:id
        def destroy
          return render_error('Cannot delete local admin account', 403) if @account.local? && @account.admin?
          
          @account.destroy!
          render json: {}
        end

        private

        def set_account
          @account = Actor.find(params[:id])
        rescue ActiveRecord::RecordNotFound
          render json: { error: 'Account not found' }, status: :not_found
        end

        def require_admin!
          return if current_user&.admin?
          
          render json: { error: 'Admin access required' }, status: :forbidden
        end

        def render_error(message, status)
          render json: { error: message }, status: status
        end

        def admin_account_json(account)
          {
            id: account.id.to_s,
            username: account.username,
            domain: account.domain,
            created_at: account.created_at.iso8601,
            email: account.local? ? "#{account.username}@localhost" : nil,
            ip: account.local? ? '127.0.0.1' : nil,
            role: account.admin? ? 'admin' : 'user',
            confirmed: true,
            suspended: account.suspended || false,
            silenced: false,
            disabled: false,
            approved: true,
            locale: 'ja',
            account: basic_account_json(account)
          }
        end

        def basic_account_json(account)
          {
            id: account.id.to_s,
            username: account.username,
            acct: account.acct,
            display_name: account.display_name_or_username,
            locked: account.manually_approves_followers,
            bot: false,
            created_at: account.created_at.iso8601,
            note: account.note || '',
            url: account.public_url,
            avatar: account.avatar_url,
            header: account.header_image_url,
            followers_count: account.followers_count || 0,
            following_count: account.following_count || 0,
            statuses_count: account.posts_count || 0,
            emojis: [],
            fields: []
          }
        end
      end
    end
  end
end