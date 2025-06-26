# frozen_string_literal: true

class AccountIdentifierParser
  def self.parse_acct_uri(acct_uri)
    return nil if acct_uri.blank?

    # acct:username@domain、@username@domain、username@domain形式を処理
    clean_uri = acct_uri.gsub(/^(acct:|@)/, '')
    parts = clean_uri.split('@')

    return nil unless parts.length == 2

    [parts[0], parts[1]]
  end

  def self.parse_acct(acct)
    return [nil, nil] if acct.blank?

    # @username@domainまたはusername@domain形式を処理
    clean_acct = acct.gsub(/^@/, '')
    parts = clean_acct.split('@')

    if parts.length == 2
      [parts[0], parts[1]]
    else
      [clean_acct, nil] # ローカルユーザ
    end
  end

  def self.build_webfinger_uri(username, domain)
    return nil if username.blank? || domain.blank?

    "acct:#{username}@#{domain}"
  end

  def self.account_query?(query)
    return false if query.blank?

    query.match?(/^@?[\w.-]+@[\w.-]+\.\w+$/) || query.start_with?('@')
  end

  def self.extract_mention_data(mention)
    return [nil, nil] if mention.blank?

    mention.split('@', 2)
  end
end
