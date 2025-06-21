# frozen_string_literal: true

module AccountSerializer
  extend ActiveSupport::Concern

  private

  def serialized_account(account, is_self: false)
    result = basic_account_attributes(account)
             .merge(image_attributes(account))
             .merge(count_attributes(account))
             .merge(metadata_attributes)

    result[:fields] = account_fields(account)
    result.merge!(self_account_attributes(account)) if is_self
    result
  end

  def basic_account_attributes(account)
    {
      id: account.id.to_s,
      username: account.username,
      acct: account_acct(account),
      display_name: account.display_name || account.username,
      locked: account.manually_approves_followers || false,
      bot: account.actor_type == 'Service',
      discoverable: account.discoverable || false,
      group: false,
      created_at: account.created_at.iso8601,
      note: account.note || '',
      url: account.public_url || account.ap_id || '',
      uri: account.ap_id || ''
    }
  end

  def image_attributes(account)
    {
      avatar: account.avatar_url || default_avatar_url,
      avatar_static: account.avatar_url || default_avatar_url,
      header: account.header_image_url || default_header_url,
      header_static: account.header_image_url || default_header_url
    }
  end

  def count_attributes(account)
    {
      followers_count: account.followers.count,
      following_count: account.followed_actors.count,
      statuses_count: account_statuses_count(account),
      last_status_at: account_last_status_at(account)
    }
  end

  def metadata_attributes
    {
      noindex: false,
      emojis: [],
      fields: []
    }
  end

  def account_fields(account)
    return [] if account.fields.blank?

    begin
      fields = JSON.parse(account.fields)
      fields.map do |field|
        {
          name: field['name'] || '',
          value: format_field_value(field['value'] || ''),
          verified_at: nil
        }
      end
    rescue JSON::ParserError
      []
    end
  end

  def account_acct(account)
    account.local? ? account.username : account.full_username
  end

  def account_statuses_count(account)
    account.objects.where(object_type: 'Note').count
  end

  def account_last_status_at(account)
    account.objects.where(object_type: 'Note').maximum(:published_at)&.to_date&.iso8601
  end

  def self_account_attributes(account)
    {
      source: {
        privacy: 'public',
        sensitive: false,
        language: 'ja',
        note: account.note || '',
        fields: account_fields(account)
      }
    }
  end

  def default_avatar_url
    '/icon.png'
  end

  def default_header_url
    '/icon.png'
  end

  def format_field_value(value)
    return '' if value.blank?

    # 既にHTMLリンクが含まれている場合はそのまま返す（外部から受信した場合）
    if value.include?('<a href=')
      value
    elsif value.match?(/\Ahttps?:\/\//)
      # プレーンなURLの場合はHTMLリンクとして返す（ローカルで設定した場合）
      domain = begin
        URI.parse(value).host
      rescue StandardError
        value
      end
      %(<a href="#{CGI.escapeHTML(value)}" target="_blank" rel="nofollow noopener noreferrer me">#{CGI.escapeHTML(domain)}</a>)
    else
      # プレーンテキストの場合はHTMLエスケープして返す
      CGI.escapeHTML(value)
    end
  rescue URI::InvalidURIError
    # URLの解析に失敗した場合はプレーンテキストとして扱う
    CGI.escapeHTML(value)
  end
end
