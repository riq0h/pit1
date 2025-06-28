# frozen_string_literal: true

class TimelineMerger
  def initialize(statuses, reblogs, limit)
    @statuses = statuses
    @reblogs = reblogs
    @limit = limit
  end

  def merge
    status_array = statuses.to_a
    reblog_array = reblogs.to_a

    return [] if status_array.empty? && reblog_array.empty?

    seen_status_ids = Set.new
    merged_items = []

    all_items = build_timeline_items(status_array, reblog_array)
    all_items.sort_by! { |item| -item[:timestamp].to_f }

    process_timeline_items(all_items, seen_status_ids, merged_items)
    merged_items
  end

  private

  attr_reader :statuses, :reblogs, :limit

  def build_timeline_items(status_array, reblog_array)
    items = status_array.map do |status|
      {
        item: status,
        timestamp: status.published_at,
        is_reblog: false,
        status_id: status.id
      }
    end

    reblog_array.each do |reblog|
      items << {
        item: reblog,
        timestamp: reblog.created_at,
        is_reblog: true,
        status_id: reblog.object_id
      }
    end

    items
  end

  def process_timeline_items(all_items, seen_status_ids, merged_items)
    all_items.each do |item_data|
      status_id = item_data[:status_id]

      next if seen_status_ids.include?(status_id)

      seen_status_ids.add(status_id)
      merged_items << item_data[:item]
      break if merged_items.length >= limit
    end
  end
end
