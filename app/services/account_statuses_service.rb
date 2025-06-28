# frozen_string_literal: true

class AccountStatusesService
  def initialize(account, params = {})
    @account = account
    @params = params
  end

  def call
    return pinned_statuses_only if pinned_only?

    regular_statuses_with_optional_pinned
  end

  private

  attr_reader :account, :params

  def pinned_only?
    params[:pinned] == 'true'
  end

  def exclude_replies?
    params[:exclude_replies] == 'true'
  end

  def only_media?
    params[:only_media] == 'true'
  end

  def limit
    params[:limit] || 20
  end

  def pinned_statuses_only
    account.pinned_statuses
           .includes(object: %i[actor media_attachments mentions tags poll])
           .ordered
           .limit(limit)
           .map(&:object)
  end

  def regular_statuses_with_optional_pinned
    regular_statuses = build_regular_statuses_query

    return regular_statuses.to_a unless first_page?

    pinned_objects = fetch_pinned_objects
    regular_without_pinned = exclude_pinned_from_regular(regular_statuses, pinned_objects)

    (pinned_objects + regular_without_pinned.to_a).first(limit)
  end

  def build_regular_statuses_query
    base_query = account.objects.where(object_type: %w[Note Question])
                        .where(local: [true, false])

    base_query = base_query.where(in_reply_to_ap_id: nil) if exclude_replies?
    base_query = base_query.joins(:media_attachments).distinct if only_media?

    paginated_query = apply_pagination(base_query)
    paginated_query.includes(:poll, :actor, :media_attachments, :mentions, :tags)
                   .order(published_at: :desc)
                   .limit(limit)
  end

  def first_page?
    params[:max_id].blank? && params[:since_id].blank? && params[:min_id].blank?
  end

  def fetch_pinned_objects
    account.pinned_statuses
           .includes(object: %i[actor media_attachments mentions tags poll])
           .ordered
           .map(&:object)
  end

  def exclude_pinned_from_regular(regular_statuses, pinned_objects)
    return regular_statuses if pinned_objects.empty?

    regular_statuses.where.not(id: pinned_objects.map(&:id))
  end

  def apply_pagination(query)
    query = query.where(objects: { id: ...(params[:max_id]) }) if params[:max_id].present?
    query = query.where('objects.id > ?', params[:since_id]) if params[:since_id].present?
    query = query.where('objects.id > ?', params[:min_id]) if params[:min_id].present?
    query
  end
end
