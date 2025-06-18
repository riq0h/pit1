# frozen_string_literal: true

module SearchHashtagSerializer
  def serialized_hashtag(hashtag)
    {
      name: hashtag.name,
      url: "#{request.base_url}/tags/#{hashtag.name}",
      history: build_hashtag_history(hashtag)
    }
  end

  private

  def build_hashtag_history(hashtag)
    [
      {
        day: Time.current.beginning_of_day.to_i.to_s,
        uses: hashtag.usage_count.to_s,
        accounts: '1'
      }
    ]
  end
end
