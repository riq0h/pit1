# frozen_string_literal: true

module ApiPagination
  extend ActiveSupport::Concern

  DEFAULT_LIMIT = 200
  MAX_LIMIT = 1000

  private

  def insert_pagination_headers
    set_pagination_headers if @paginated_items.present?
  end

  def set_pagination_headers(items = @paginated_items)
    response.headers['Link'] = pagination_links(items)
    response.headers['X-Total-Count'] = total_count(items).to_s if include_total_count?
  end

  def pagination_links(items)
    links = []
    
    # Get the actual records (handle both arrays and AR relations)
    records = items.respond_to?(:to_a) ? items.to_a : items
    
    return '' if records.empty?

    # Extract IDs from records
    ids = extract_ids(records)
    
    # Build pagination links
    links << link_next(ids) if ids.size >= limit_param
    links << link_prev(ids) if ids.any?
    
    links.compact.join(', ')
  end

  def extract_ids(records)
    records.map do |record|
      case record
      when ActivityPubObject
        record.id
      when Reblog
        # For reblogs, use the reblogged object's ID for consistency
        record.object_id
      when Hash
        # Handle timeline items that are hashes with object key
        if record[:object].is_a?(ActivityPubObject)
          record[:object].id
        elsif record[:object].is_a?(Reblog)
          record[:object].object_id
        else
          nil
        end
      else
        record.id if record.respond_to?(:id)
      end
    end.compact
  end

  def link_next(ids)
    return unless ids.any?
    
    # The last ID in the current page becomes max_id for next page
    max_id = ids.last
    "<#{api_pagination_url(max_id: max_id)}>; rel=\"next\""
  end

  def link_prev(ids)
    return unless ids.any?
    
    # The first ID in the current page becomes since_id for prev page
    since_id = ids.first
    "<#{api_pagination_url(since_id: since_id)}>; rel=\"prev\""
  end

  def api_pagination_url(params_hash)
    url_params = request.query_parameters.merge(params_hash)
    
    # Remove conflicting parameters
    if params_hash[:max_id]
      url_params.delete(:since_id)
      url_params.delete(:min_id)
    elsif params_hash[:since_id]
      url_params.delete(:max_id)
      url_params.delete(:min_id)
    end
    
    # Ensure limit is included
    url_params[:limit] = limit_param
    
    # Build URL
    "#{request.base_url}#{request.path}?#{url_params.to_query}"
  end

  def limit_param
    return DEFAULT_LIMIT unless params[:limit].present?
    
    [params[:limit].to_i, MAX_LIMIT].min
  end

  def max_id_param
    params[:max_id]&.to_i
  end

  def since_id_param
    params[:since_id]&.to_i
  end

  def min_id_param
    params[:min_id]&.to_i
  end

  def include_total_count?
    # Optional: Add total count header for some endpoints
    false
  end

  def total_count(items)
    return items.count if items.respond_to?(:count)
    items.size
  end

  # Helper method to paginate and set headers in one call
  def paginate_with_headers(items)
    @paginated_items = items
    insert_pagination_headers
    items
  end
end