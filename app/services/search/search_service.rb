# frozen_string_literal: true

module Search
  class SearchService
    def initialize(params, current_user)
      @params = params
      @current_user = current_user
      @remote_resolver = RemoteResolverService.new
    end

    def perform_search
      {
        accounts: search_accounts,
        statuses: search_statuses,
        hashtags: search_hashtags
      }
    end

    private

    attr_reader :params, :current_user, :remote_resolver

    def search_accounts
      return [] if search_query.blank?

      accounts = []
      accounts.concat(resolve_remote_accounts) if should_resolve_remote_accounts?
      accounts.concat(search_local_accounts) if should_search_local_accounts?
      accounts.uniq(&:id)
    end

    def search_statuses
      return [] if search_query.blank?

      statuses = []
      statuses.concat(resolve_remote_statuses) if should_resolve_remote_statuses?
      statuses.concat(search_local_statuses) if should_search_local_statuses?
      statuses.uniq(&:id)
    end

    def search_hashtags
      return [] if search_query.blank?
      return [] if %w[accounts statuses].include?(search_type)

      tag_query = search_query.gsub(/^#/, '')
      Tag.where('name LIKE ?', "%#{tag_query}%")
         .order(usage_count: :desc)
         .limit(hashtag_limit)
    end

    def resolve_remote_accounts
      return [] unless resolve_remote? && account_query?

      remote_account = remote_resolver.resolve_remote_account(search_query)
      remote_account ? [remote_account] : []
    end

    def resolve_remote_statuses
      return [] unless resolve_remote? && url_query?

      remote_status = remote_resolver.resolve_remote_status(search_query)
      remote_status ? [remote_status] : []
    end

    def search_local_accounts
      return [] unless should_search_local_accounts?

      Actor.where(local: true)
           .where('username LIKE ? OR display_name LIKE ?',
                  "%#{search_query}%", "%#{search_query}%")
           .limit(account_limit)
    end

    def search_local_statuses
      return [] unless should_search_local_statuses?

      search_service = OptimizedSearchService.new(
        query: search_query,
        since_time: parse_time(params[:since]),
        until_time: parse_time(params[:until]),
        limit: status_limit,
        offset: params[:offset].to_i
      )
      search_service.search
    end

    def should_resolve_remote_accounts?
      resolve_remote? && account_query?
    end

    def should_resolve_remote_statuses?
      resolve_remote? && url_query?
    end

    def should_search_local_accounts?
      %w[statuses hashtags].exclude?(search_type)
    end

    def should_search_local_statuses?
      %w[accounts hashtags].exclude?(search_type)
    end

    def search_query
      params[:q].to_s.strip
    end

    def search_type
      params[:type]&.to_s
    end

    def resolve_remote?
      params[:resolve] == 'true' && current_user
    end

    def account_query?
      search_query.match?(/^@?[\w.-]+@[\w.-]+\.\w+$/) || search_query.start_with?('@')
    end

    def url_query?
      search_query.match?(/^https?:\/\//)
    end

    def account_limit
      return 0 if %w[statuses hashtags].include?(search_type)

      [params[:limit].to_i, 40].min.positive? ? [params[:limit].to_i, 40].min : 20
    end

    def status_limit
      return 0 if %w[accounts hashtags].include?(search_type)

      [params[:limit].to_i, 40].min.positive? ? [params[:limit].to_i, 40].min : 20
    end

    def hashtag_limit
      return 0 if %w[accounts statuses].include?(search_type)

      [params[:limit].to_i, 40].min.positive? ? [params[:limit].to_i, 40].min : 20
    end

    def parse_time(time_param)
      return nil if time_param.blank?

      Time.zone.parse(time_param)
    rescue ArgumentError
      nil
    end
  end
end
