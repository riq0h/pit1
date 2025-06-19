# frozen_string_literal: true

module Api
  module V1
    module Admin
      class ReportsController < Api::BaseController
        before_action :doorkeeper_authorize!
        before_action :require_admin!

        # GET /api/v1/admin/reports
        def index
          # Letterでは簡素化されたレポート機能
          # 実際のレポートシステムは今回は未実装
          render json: []
        end

        # GET /api/v1/admin/reports/:id
        def show
          render json: { error: 'Report not found' }, status: :not_found
        end

        # POST /api/v1/admin/reports/:id/assign_to_self
        def assign_to_self
          render json: { error: 'Reports are not implemented in Letter' }, status: :not_implemented
        end

        # POST /api/v1/admin/reports/:id/unassign
        def unassign
          render json: { error: 'Reports are not implemented in Letter' }, status: :not_implemented
        end

        # POST /api/v1/admin/reports/:id/resolve
        def resolve
          render json: { error: 'Reports are not implemented in Letter' }, status: :not_implemented
        end

        # POST /api/v1/admin/reports/:id/reopen
        def reopen
          render json: { error: 'Reports are not implemented in Letter' }, status: :not_implemented
        end

        private

        def require_admin!
          return if current_user&.admin?
          
          render json: { error: 'Admin access required' }, status: :forbidden
        end
      end
    end
  end
end