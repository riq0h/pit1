# frozen_string_literal: true

module AccountSerializer
  extend ActiveSupport::Concern
  include StatusSerializer
  include TextLinkingHelper

  private

  def serialized_account(account, is_self: false)
    result = basic_account_attributes(account)
             .merge(image_attributes(account))
             .merge(count_attributes(account))
             .merge(metadata_attributes)

    result[:fields] = account_fields(account)
    result[:emojis] = account_emojis(account)
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
      note: format_text_for_api(account.note || ''),
      note_html: format_text_for_client(account.note || ''),
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

  def account_emojis(account)
    return [] if account.display_name.blank? && account.note.blank? && account.fields.blank?

    # display_nameとnoteからemoji shortcodeを抽出
    text_content = [account.display_name, account.note].compact.join(' ')
    
    # fieldsからもemoji shortcodeを抽出
    if account.fields.present?
      begin
        fields = JSON.parse(account.fields)
        field_content = fields.map { |f| [f['name'], f['value']].compact.join(' ') }.join(' ')
        text_content += " #{field_content}"
      rescue JSON::ParserError
        # JSON解析エラーの場合は無視
      end
    end

    # emojis抽出
    emojis = EmojiParser.new(text_content).emojis_used
    emojis.map(&:to_activitypub)
  rescue StandardError => e
    Rails.logger.warn "Failed to serialize account emojis for actor #{account.id}: #{e.message}"
    []
  end

  def account_fields(account)
    return [] if account.fields.blank?

    begin
      fields = JSON.parse(account.fields)
      fields.map do |field|
        {
          name: field['name'] || '',
          value: format_field_value_for_api(field['value'] || ''),
          value_html: format_field_value_for_client(field['value'] || ''),
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

  # クライアント用のテキスト処理（emoji + URLリンク化）
  def format_text_for_client(text)
    return '' if text.blank?

    # 1. emoji解析
    text_with_emoji = parse_content_for_frontend(text)
    # 2. URLリンク化
    auto_link_urls(text_with_emoji)
  end

  # クライアント用のフィールドvalue処理（emoji + URLリンク化）
  def format_field_value_for_client(value)
    return '' if value.blank?

    # emoji解析
    value_with_emoji = parse_content_for_frontend(value)
    # URLリンク化
    auto_link_urls(value_with_emoji)
  end

  # API用のテキスト処理（ショートコード + URLリンク化）
  def format_text_for_api(text)
    return '' if text.blank?

    # HTMLエスケープ後URLリンク化のみ（絵文字はショートコードのまま）
    escaped_text = CGI.escapeHTML(text).gsub("\n", '<br>')
    apply_url_links(escaped_text)
  end

  # API用のフィールドvalue処理（ショートコード + URLリンク化）
  def format_field_value_for_api(value)
    return '' if value.blank?

    # 既にHTMLリンクが含まれている場合はそのまま返す（外部から受信した場合）
    return value if value.include?('<a href=')

    # プレーンなURLの場合はHTMLリンクとして返す（ローカルで設定した場合）
    if value.match?(/\Ahttps?:\/\//)
      domain = URI.parse(value).host rescue value
      %(<a href="#{CGI.escapeHTML(value)}" target="_blank" rel="nofollow noopener noreferrer me">#{CGI.escapeHTML(domain)}</a>)
    else
      # プレーンテキストの場合はHTMLエスケープしてURLリンク化のみ
      escaped_value = CGI.escapeHTML(value)
      apply_url_links(escaped_value)
    end
  rescue URI::InvalidURIError
    CGI.escapeHTML(value)
  end

  private

  def apply_url_links(text)
    link_pattern = /(https?:\/\/[^\s]+)/
    link_template = '<a href="\1" target="_blank" rel="noopener noreferrer" ' \
                    'class="text-blue-600 hover:text-blue-800 underline">' \
                    '\1</a>'
    text.gsub(link_pattern, link_template)
  end

end
