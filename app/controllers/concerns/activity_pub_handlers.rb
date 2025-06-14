# frozen_string_literal: true

module ActivityPubHandlers
  extend ActiveSupport::Concern

  include ActivityPubFollowHandlers
  include ActivityPubInteractionHandlers
end
