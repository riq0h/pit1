# frozen_string_literal: true

module TagSerializer
  extend ActiveSupport::Concern

  private

  def serialized_tag(tag, include_history: true)
    result = {
      name: tag.name,
      url: "#{request.base_url}/tags/#{tag.name}"
    }

    result[:history] = if include_history
                         [
                           {
                             day: Time.current.to_date.to_s,
                             uses: tag.usage_count.to_s,
                             accounts: '1' # 簡素化
                           }
                         ]
                       else
                         []
                       end

    result
  end
end
