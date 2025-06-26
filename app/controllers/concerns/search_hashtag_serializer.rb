# frozen_string_literal: true

module SearchHashtagSerializer
  include HashtagHistoryBuilder

  def serialized_hashtag(hashtag)
    {
      name: hashtag.name,
      url: "#{request.base_url}/tags/#{hashtag.name}",
      history: build_hashtag_history(hashtag)
    }
  end
end
