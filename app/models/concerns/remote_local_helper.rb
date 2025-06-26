# frozen_string_literal: true

module RemoteLocalHelper
  extend ActiveSupport::Concern

  def remote?
    !local?
  end
end
