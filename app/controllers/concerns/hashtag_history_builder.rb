# frozen_string_literal: true

module HashtagHistoryBuilder
  def build_hashtag_history(hashtag)
    [
      {
        day: Time.current.beginning_of_day.to_i.to_s,
        uses: (hashtag.usage_count || 0).to_s,
        accounts: '1'
      }
    ]
  end
end
