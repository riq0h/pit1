# frozen_string_literal: true

module ActivityPubInteractionHandlers
  extend ActiveSupport::Concern

  include ActivityPubAnnounceHandlers
  include ActivityPubLikeHandlers
  include ActivityPubUtilityHelpers
end
