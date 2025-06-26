# frozen_string_literal: true

module AdminAuthorization
  extend ActiveSupport::Concern

  private

  def require_admin!
    return if current_user&.admin?

    render_admin_required
  end
end
