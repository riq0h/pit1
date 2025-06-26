# frozen_string_literal: true

module ActivityPubHelper
  def fetch_activitypub_object(uri)
    ActivityPubHttpClient.fetch_object(uri)
  end
end
