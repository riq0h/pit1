Rails.application.configure do
  # ActivityPub設定
  config.activitypub = ActiveSupport::OrderedOptions.new

  # ドメイン設定
  config.activitypub.domain = ENV.fetch('ACTIVITYPUB_DOMAIN') do
    if Rails.env.development?
      'localhost:3000'
    elsif Rails.env.test?
      'test.example'
    else
      raise 'ACTIVITYPUB_DOMAIN environment variable is required in production'
    end
  end

  # 投稿制限
  config.activitypub.character_limit = 9999
  config.activitypub.max_accounts = 2

  # メディア制限
  config.activitypub.max_image_size = 10.megabytes
  config.activitypub.max_video_size = 100.megabytes
  config.activitypub.max_audio_size = 50.megabytes
  config.activitypub.max_document_size = 20.megabytes

  # フェデレーション設定
  config.activitypub.federation_enabled = ENV.fetch('FEDERATION_ENABLED', 'true') == 'true'
  config.activitypub.http_timeout = 10.seconds
  config.activitypub.max_redirects = 3

  # セキュリティ設定
  config.activitypub.require_http_signatures = Rails.env.production?
  config.activitypub.signature_algorithm = 'rsa-sha256'

  # インスタンス情報
  config.instance_name = ENV.fetch('INSTANCE_NAME', 'pit1 ActivityPub Server')
  config.instance_description = ENV.fetch('INSTANCE_DESCRIPTION',
                                          'A lightweight ActivityPub server built with Rails 8 and SQLite')
  config.instance_contact_email = ENV.fetch('CONTACT_EMAIL', 'admin@localhost')
  config.instance_maintainer = ENV.fetch('MAINTAINER_NAME', 'pit1 Administrator')

  # UI設定
  config.activitypub.default_locale = 'ja'
  config.activitypub.supported_locales = %w[ja en]

  # ログ設定
  config.activitypub.log_level = Rails.env.production? ? :info : :debug
end

# バリデーション
Rails.application.config.after_initialize do
  domain = Rails.application.config.activitypub.domain

  if Rails.env.production?
    unless domain.present? && domain.include?('.')
      Rails.logger.error "Invalid ActivityPub domain: #{domain}"
      raise 'ActivityPub domain must be a valid domain name in production'
    end

    if domain.include?('localhost')
      Rails.logger.error 'localhost is not allowed in production'
      raise 'ActivityPub domain cannot be localhost in production'
    end
  end

  Rails.logger.info "ActivityPub configured for domain: #{domain}"
end
