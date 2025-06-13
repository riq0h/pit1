# frozen_string_literal: true

class OptimizedSearchService
  include ActiveModel::Model

  attr_accessor :query, :since_time, :until_time, :limit, :offset

  def initialize(attributes = {})
    super
    @limit ||= 20
    @offset ||= 0
  end

  def search
    return [] if query.blank?

    if since_time.present? || until_time.present?
      search_with_time_range
    else
      search_full_text_only
    end
  end

  def timeline(max_id: nil, min_id: nil)
    base_query = ActivityPubObject.joins(:actor)
                                  .where(object_type: 'Note')
                                  .where(local: true)
                                  .where(visibility: 'public')

    base_query = base_query.where(objects: { id: ...max_id }) if max_id.present?
    base_query = base_query.where('objects.id > ?', min_id) if min_id.present?
    base_query.order('objects.id DESC').limit(limit)
  end

  def user_posts(actor_id, max_id: nil)
    base_query = ActivityPubObject.where(actor_id: actor_id)
                                  .where(object_type: 'Note')
                                  .where(visibility: %w[public unlisted])

    base_query = base_query.where(objects: { id: ...max_id }) if max_id.present?
    base_query.order('objects.id DESC').limit(limit)
  end

  def posts_in_time_range(start_time, end_time)
    start_id = time_to_snowflake_id(start_time)
    end_id = time_to_snowflake_id(end_time)

    ActivityPubObject.where('objects.id BETWEEN ? AND ?', start_id, end_id)
                     .where(object_type: 'Note')
                     .where(local: true)
                     .order('objects.id DESC')
                     .limit(limit)
  end

  def user_posts_search(target_actor_id)
    return [] if query.blank?

    object_ids = matching_object_ids
    return [] if object_ids.empty?

    ActivityPubObject.where(id: object_ids)
                     .where(actor_id: target_actor_id)
                     .where(object_type: 'Note')
                     .where(visibility: %w[public unlisted])
                     .includes(:actor)
                     .order('objects.id DESC')
  end

  private

  def search_with_time_range
    since_id = since_time.present? ? time_to_snowflake_id(since_time) : nil
    until_id = until_time.present? ? time_to_snowflake_id(until_time) : nil
    fts5_query = build_fts5_query

    if since_id && until_id
      fts5_query += " AND object_id BETWEEN '#{since_id}' AND '#{until_id}'"
    elsif since_id
      fts5_query += " AND object_id >= '#{since_id}'"
    elsif until_id
      fts5_query += " AND object_id <= '#{until_id}'"
    end

    execute_fts5_search(fts5_query)
  end

  def search_full_text_only
    execute_fts5_search(build_fts5_query)
  end

  def build_fts5_query
    if query.include?(' ')
      keywords = query.split(/\s+/).map { |word| "\"#{word}\"" }
      keywords.join(' AND ')
    else
      "\"#{query}\""
    end
  end

  def execute_fts5_search(_fts5_query)
    object_ids = matching_object_ids
    return [] if object_ids.empty?

    ActivityPubObject.where(id: object_ids)
                     .includes(:actor)
                     .order('objects.id DESC')
  end

  def matching_object_ids
    # FTS5が日本語で機能しない場合はLIKE検索にフォールバック
    sql = <<~SQL.squish
      SELECT object_id, content_plaintext, summary
      FROM letter_post_search#{' '}
      WHERE content_plaintext LIKE ?
      ORDER BY object_id DESC
      LIMIT ? OFFSET ?
    SQL

    like_query = "%#{query}%"
    results = ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql([sql, like_query, limit, offset])
    )

    results.pluck('object_id')
  end

  def time_to_snowflake_id(time)
    Letter::Snowflake.generate_at(time, sequence: 0)
  end

  def snowflake_id_to_time(snowflake_id)
    Letter::Snowflake.extract_timestamp(snowflake_id)
  rescue StandardError
    nil
  end
end
