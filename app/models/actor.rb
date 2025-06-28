# frozen_string_literal: true

class Actor < ApplicationRecord
  include UrlBuildable
  has_secure_password validations: false

  attribute :settings, :json, default: -> { {} }

  # アソシエーション
  has_many :objects, dependent: :destroy, class_name: 'ActivityPubObject'
  has_many :activities, dependent: :destroy
  has_many :media_attachments, dependent: :destroy
  has_many :favourites, dependent: :destroy
  has_many :reblogs, dependent: :destroy
  has_many :mentions, dependent: :destroy
  has_many :bookmarks, dependent: :destroy
  has_many :featured_tags, dependent: :destroy
  has_many :followed_tags, dependent: :destroy
  has_many :quote_posts, dependent: :destroy
  has_many :markers, dependent: :destroy
  has_many :scheduled_statuses, dependent: :destroy
  has_many :poll_votes, dependent: :destroy
  has_many :pinned_statuses, dependent: :destroy
  has_many :lists, dependent: :destroy
  has_many :list_memberships, dependent: :destroy
  has_many :filters, dependent: :destroy
  has_many :web_push_subscriptions, dependent: :destroy
  has_many :notifications, dependent: :destroy, foreign_key: :account_id, inverse_of: :account
  has_many :sent_notifications, dependent: :destroy, foreign_key: :from_account_id, class_name: 'Notification', inverse_of: :from_account

  # Active Storage統合
  has_one_attached :avatar
  has_one_attached :header

  # カスタムアップロードメソッド（フォルダ構造対応）
  def attach_avatar_with_folder(io:, filename:, content_type:)
    if ENV['S3_ENABLED'] == 'true'
      custom_key = "avatar/#{SecureRandom.hex(16)}"
      blob = ActiveStorage::Blob.create_and_upload!(
        io: io,
        filename: filename,
        content_type: content_type,
        service_name: :cloudflare_r2,
        key: custom_key
      )
      avatar.attach(blob)
    else
      avatar.attach(io: io, filename: filename, content_type: content_type)
    end
  end

  # フォロー関係
  has_many :following_relationships, class_name: 'Follow', dependent: :destroy, inverse_of: :actor
  has_many :following, through: :following_relationships, source: :target_actor
  has_many :follower_relationships, class_name: 'Follow', foreign_key: :target_actor_id, dependent: :destroy, inverse_of: :target_actor
  has_many :followers, through: :follower_relationships, source: :actor

  # ブロック・ミュート関係
  has_many :blocks, dependent: :destroy
  has_many :blocked_actors, through: :blocks, source: :target_actor
  has_many :blocked_by, class_name: 'Block', foreign_key: :target_actor_id, dependent: :destroy, inverse_of: :target_actor
  has_many :blocking_actors, through: :blocked_by, source: :actor

  has_many :mutes, dependent: :destroy
  has_many :muted_actors, through: :mutes, source: :target_actor
  has_many :muted_by, class_name: 'Mute', foreign_key: :target_actor_id, dependent: :destroy, inverse_of: :target_actor
  has_many :muting_actors, through: :muted_by, source: :actor

  # ドメインブロック
  has_many :domain_blocks, dependent: :destroy

  # アカウントメモ
  has_many :account_notes, dependent: :destroy
  has_many :account_notes_received, class_name: 'AccountNote', foreign_key: :target_actor_id, dependent: :destroy, inverse_of: :target_actor

  # 会話
  has_many :conversation_participants, dependent: :destroy
  has_many :conversations, through: :conversation_participants

  # OAuth 2.0関連
  has_many :access_grants,
           class_name: 'Doorkeeper::AccessGrant',
           foreign_key: :resource_owner_id,
           dependent: :delete_all,
           inverse_of: :resource_owner

  has_many :access_tokens,
           class_name: 'Doorkeeper::AccessToken',
           foreign_key: :resource_owner_id,
           dependent: :delete_all,
           inverse_of: :resource_owner

  # フォロー関係
  has_many :follows, dependent: :destroy
  has_many :followed_actors, through: :follows, source: :target_actor
  has_many :reverse_follows, class_name: 'Follow', foreign_key: 'target_actor_id', dependent: :destroy, inverse_of: :target_actor

  # バリデーション
  validates :username, presence: true, format: { with: /\A[a-zA-Z0-9_]+\z/ }
  validates :ap_id, presence: true, uniqueness: true, if: -> { !local? || !new_record? }
  validates :inbox_url, presence: true, if: -> { !local? || !new_record? }
  validates :outbox_url, presence: true, if: -> { !local? || !new_record? }
  validates :public_key, presence: true, if: -> { !local? || !new_record? }
  validates :password, length: { minimum: 6 }, if: -> { local? && password.present? }

  # ローカルアクター制限（SQLiteトリガーで制御）
  validate :local_actor_limit, if: -> { local? && !Rails.env.test? }

  # スコープ
  scope :local, -> { where(local: true) }
  scope :remote, -> { where(local: false) }
  scope :discoverable, -> { where(discoverable: true) }

  # コールバック
  before_validation :set_ap_urls, if: :local?, on: :create
  before_validation :generate_key_pair, if: :local?, on: :create
  before_create :set_admin_for_local_users, if: :local?
  after_update :distribute_profile_update, if: :should_distribute_profile_update?

  def setting(key)
    settings[key.to_s]
  end

  def update_setting(key, value)
    update!(settings: settings.merge(key.to_s => value))
  end

  def default_settings
    {
      'posting:default:visibility' => 'public',
      'posting:default:sensitive' => false,
      'posting:default:language' => 'ja',
      'reading:expand:media' => 'default',
      'reading:expand:spoilers' => false,
      'reading:autoplay:gifs' => true,
      'web:advanced_layout' => false,
      'web:use_blurhash' => true,
      'web:use_pending_items' => false,
      'web:trends' => true,
      'notification_emails' => {
        'follow' => true,
        'reblog' => true,
        'favourite' => true,
        'mention' => true,
        'follow_request' => true,
        'digest' => true
      }
    }
  end

  def preferences
    default_settings.merge(settings || {})
  end

  # ActivityPub URL
  def followers_url
    return super if super.present?

    "#{ap_id}/followers" if local? && ap_id.present?
  end

  def following_url
    return super if super.present?

    "#{ap_id}/following" if local? && ap_id.present?
  end

  def featured_url
    return super if super.present?

    "#{ap_id}/collections/featured" if local? && ap_id.present?
  end

  # WebFinger識別子
  def webfinger_subject
    local_domain = Rails.application.config.activitypub.domain
    "acct:#{username}@#{domain || local_domain}"
  end

  # パブリック HTML URL
  def public_url
    return nil unless local?

    base_url = Rails.application.config.activitypub.base_url
    "#{base_url}/@#{username}"
  end

  # 表示メソッド
  def display_name_or_username
    display_name.presence || username
  end

  def full_username
    local? ? username : "#{username}@#{domain}"
  end

  # キー管理
  def public_key_object
    @public_key_object ||= OpenSSL::PKey::RSA.new(public_key) if public_key.present?
  end

  def private_key_object
    @private_key_object ||= OpenSSL::PKey::RSA.new(private_key) if private_key.present?
  end

  def public_key_id
    "#{ap_id}#main-key"
  end

  # アクティビティ生成
  def generate_follow_activity(target_actor, follow_id)
    {
      '@context' => Rails.application.config.activitypub.context_url,
      'type' => 'Follow',
      'id' => "#{ap_id}#follows/#{follow_id}",
      'actor' => ap_id,
      'object' => target_actor.ap_id
    }
  end

  def generate_accept_activity(follow)
    {
      '@context' => Rails.application.config.activitypub.context_url,
      'type' => 'Accept',
      'id' => "#{ap_id}#accepts/follows/#{follow.id}",
      'actor' => ap_id,
      'object' => {
        'type' => 'Follow',
        'id' => follow.follow_activity_ap_id,
        'actor' => follow.actor.ap_id,
        'object' => ap_id
      }
    }
  end

  # ActivityPub JSON-LD representation
  def to_activitypub(request = nil)
    base_activitypub_data(request).merge(activitypub_links(request)).merge(activitypub_images(request)).merge(activitypub_attachments).merge(activitypub_tags).compact
  end

  # フォロー・フォロワー数の更新
  def update_following_count!
    count = following_relationships.accepted.count
    update_column(:following_count, count)
  end

  def update_followers_count!
    count = follower_relationships.accepted.count
    update_column(:followers_count, count)
  end

  # 投稿数の更新
  def update_posts_count!
    count = objects.where(object_type: 'Note', local: true).count
    update_column(:posts_count, count)
  end

  # ブロック・ミュートヘルパーメソッド
  def blocking?(actor)
    return false unless actor

    blocks.exists?(target_actor: actor)
  end

  def blocked_by?(actor)
    return false unless actor

    blocked_by.exists?(actor: actor)
  end

  def muting?(actor)
    return false unless actor

    mutes.exists?(target_actor: actor)
  end

  def muted_by?(actor)
    return false unless actor

    muted_by.exists?(actor: actor)
  end

  def domain_blocking?(domain)
    return false unless domain

    domain_blocks.exists?(domain: domain)
  end

  def domain_blocked_by?(actor_domain)
    return false unless actor_domain && domain.present?

    DomainBlock.exists?(domain: domain)
  end

  # Mastodon互換のacctメソッド
  def acct
    local? ? username : "#{username}@#{domain}"
  end

  # Active Storage画像URLの取得
  def avatar_url
    # ローカルユーザの場合はActiveStorageから取得
    if local? && avatar.attached?
      # Cloudflare R2のカスタムドメインを使用
      if ENV['S3_ENABLED'] == 'true' && ENV['S3_ALIAS_HOST'].present?
        "https://#{ENV.fetch('S3_ALIAS_HOST', nil)}/#{avatar.blob.key}"
      else
        Rails.application.routes.url_helpers.url_for(avatar)
      end
    else
      # 外部ユーザの場合はraw_dataから取得
      extract_remote_image_url('icon')
    end
  end

  def header_image_url
    # ローカルユーザの場合はActiveStorageから取得
    if local? && header.attached?
      # Cloudflare R2のカスタムドメインを使用
      if ENV['S3_ENABLED'] == 'true' && ENV['S3_ALIAS_HOST'].present?
        "https://#{ENV.fetch('S3_ALIAS_HOST', nil)}/#{header.blob.key}"
      else
        Rails.application.routes.url_helpers.url_for(header)
      end
    else
      # 外部ユーザの場合はraw_dataから取得
      extract_remote_image_url('image')
    end
  end

  def extract_remote_image_url(field_name)
    return nil if raw_data.blank?

    begin
      actor_data = parse_actor_data
      return nil unless actor_data

      extract_image_url(actor_data[field_name])
    rescue JSON::ParserError => e
      log_parse_error(e)
      nil
    rescue StandardError => e
      log_extraction_error(field_name, e)
      nil
    end
  end

  private

  def parse_actor_data
    case raw_data
    when String
      parse_raw_data_string(raw_data)
    when Hash
      raw_data
    end
  end

  def log_parse_error(error)
    Rails.logger.warn "Failed to parse raw_data for #{username}@#{domain}: #{error.message}"
  end

  def log_extraction_error(field_name, error)
    Rails.logger.warn "Failed to extract #{field_name} URL for #{username}@#{domain}: #{error.message}"
  end

  # raw_data文字列をパース（JSON形式またはRuby Hash形式に対応）
  def parse_raw_data_string(data_string)
    # まずJSONとしてパースを試行
    begin
      return JSON.parse(data_string)
    rescue JSON::ParserError
      # JSONでない場合は、Ruby Hash文字列として安全にパースを試行
      # evalの代わりにYAMLを使用して安全にパース
      begin
        if data_string.start_with?('{') && data_string.end_with?('}')
          # Ruby Hash文字列をYAML形式に変換してパース
          # ただし、これも完全に安全ではないため、JSON以外は受け付けない方針とする
          Rails.logger.warn "Non-JSON data_string received: #{data_string[0..100]}..."
          return nil
        end
      rescue StandardError => e
        Rails.logger.error "Failed to parse data_string: #{e.message}"
      end
    end

    nil
  end

  # 画像URL抽出ヘルパー
  def extract_image_url(image_data)
    return nil if image_data.blank?

    case image_data
    when String
      image_data
    when Hash
      image_data['url'] || image_data['href']
    when Array
      image_data.first&.dig('url') || image_data.first&.dig('href')
    end
  end

  # ActivityPub base data
  def base_activitypub_data(request = nil)
    base_url = get_base_url(request)
    actor_url = "#{base_url}/users/#{username}"

    {
      '@context' => [
        Rails.application.config.activitypub.context_url,
        'https://w3id.org/security/v1',
        {
          'schema' => 'http://schema.org#',
          'PropertyValue' => 'schema:PropertyValue',
          'value' => 'schema:value'
        }
      ],
      'type' => actor_type || 'Person',
      'id' => actor_url,
      'preferredUsername' => username,
      'name' => convert_emoji_html_to_shortcode(display_name),
      'summary' => convert_emoji_html_to_shortcode(note),
      'url' => actor_url,
      'discoverable' => discoverable,
      'manuallyApprovesFollowers' => manually_approves_followers
    }
  end

  # ActivityPub URL
  def activitypub_links(request = nil)
    base_url = get_base_url(request)
    actor_url = "#{base_url}/users/#{username}"

    {
      'inbox' => "#{actor_url}/inbox",
      'outbox' => "#{actor_url}/outbox",
      'followers' => "#{actor_url}/followers",
      'following' => "#{actor_url}/following",
      'featured' => "#{actor_url}/collections/featured",
      'endpoints' => {
        'sharedInbox' => "#{base_url}/inbox"
      },
      'publicKey' => {
        'id' => "#{actor_url}#main-key",
        'owner' => actor_url,
        'publicKeyPem' => public_key
      }
    }
  end

  # ActivityPub images
  def activitypub_images(_request = nil)
    {
      'icon' => avatar_url ? { 'type' => 'Image', 'url' => avatar_url } : nil,
      'image' => header_image_url ? { 'type' => 'Image', 'url' => header_image_url } : nil
    }
  end

  # ActivityPub profile attachments (PropertyValue)
  def activitypub_attachments
    return {} if fields.blank?

    begin
      links = JSON.parse(fields)
      attachments = links.filter_map do |link|
        next if link['name'].blank? || link['value'].blank?

        {
          'type' => 'PropertyValue',
          'name' => convert_emoji_html_to_shortcode(link['name']),
          'value' => format_profile_link_value_for_activitypub(link['value'])
        }
      end

      attachments.empty? ? {} : { 'attachment' => attachments }
    rescue JSON::ParserError
      {}
    end
  end

  # ActivityPub用のプロフィールリンクvalue形式化（HTML内のemojiもショートコード化）
  def format_profile_link_value_for_activitypub(value)
    converted_value = convert_emoji_html_to_shortcode(value)
    return converted_value unless converted_value.match?(/\Ahttps?:\/\//)

    begin
      domain = begin
        URI.parse(converted_value).host
      rescue StandardError
        converted_value
      end
      %(<a href="#{CGI.escapeHTML(converted_value)}" target="_blank" rel="nofollow noopener noreferrer me">#{CGI.escapeHTML(domain)}</a>)
    rescue URI::InvalidURIError
      CGI.escapeHTML(converted_value)
    end
  end

  # HTMLの<img>タグをショートコード形式に変換
  def convert_emoji_html_to_shortcode(text)
    return text if text.blank?

    # <img ... alt=":shortcode:" ...> を :shortcode: に変換
    text.gsub(/<img[^>]*alt=":([^"]+):"[^>]*\/?>/, ':\1:')
  end

  # ActivityPub tags (emoji情報)
  def activitypub_tags
    emoji_tags = extract_actor_emojis
    emoji_tags.empty? ? {} : { 'tag' => emoji_tags }
  end

  # アクターのプロフィールからemoji情報を抽出
  def extract_actor_emojis
    # display_name、note、fieldsからemoji shortcodeを抽出
    text_content = [display_name, note].compact.join(' ')

    # fieldsからもemoji shortcodeを抽出
    if fields.present?
      begin
        fields_data = JSON.parse(fields)
        field_content = fields_data.map { |f| [f['name'], f['value']].compact.join(' ') }.join(' ')
        text_content += " #{field_content}"
      rescue JSON::ParserError
        # JSON解析エラーの場合は無視
      end
    end

    # emojis抽出
    emoji_regex = /:([a-zA-Z0-9_]+):/
    shortcodes = text_content.scan(emoji_regex).flatten.uniq
    return [] if shortcodes.empty?

    # ローカル絵文字のみを対象
    emojis = CustomEmoji.enabled.local.where(shortcode: shortcodes)
    emojis.map(&:to_ap)
  rescue StandardError => e
    Rails.logger.warn "Failed to extract actor emojis for actor #{id}: #{e.message}"
    []
  end

  # ベースURL取得
  def get_base_url(_request = nil)
    # 常に設定からのドメインを使用（.envで設定されたACTIVITYPUB_DOMAINを優先）
    build_url_from_config
  end

  # RSA鍵ペア生成
  def generate_key_pair
    return unless local? && private_key.blank?

    rsa_key = OpenSSL::PKey::RSA.new(2048)

    self.private_key = rsa_key.to_pem
    self.public_key = rsa_key.public_key.to_pem
  end

  # ActivityPub URL設定
  def set_ap_urls
    return unless local?

    set_primary_ap_urls
    set_collection_ap_urls
  end

  # ローカルアクター数制限（SQLiteトリガーと連携）
  def local_actor_limit
    return unless local?

    local_count = Actor.where(local: true).where.not(id: id).count

    return unless local_count >= 2

    errors.add(:local, 'Maximum number of local accounts reached')
  end

  # すべてのローカルユーザを自動的にadminにする
  def set_admin_for_local_users
    self.admin = true if local?
  end

  def set_primary_ap_urls
    base_url = Rails.application.config.activitypub.base_url
    user_base = "#{base_url}/users/#{username}"

    self.ap_id ||= user_base
    self.inbox_url ||= "#{user_base}/inbox"
    self.outbox_url ||= "#{user_base}/outbox"
  end

  def set_collection_ap_urls
    base_url = Rails.application.config.activitypub.base_url
    user_base = "#{base_url}/users/#{username}"

    self[:followers_url] ||= "#{user_base}/followers"
    self[:following_url] ||= "#{user_base}/following"
    self.featured_url ||= "#{user_base}/collections/featured"
  end

  public

  # フォロー実行
  def follow!(target_actor_or_uri)
    follow_service = FollowService.new(self)
    follow_service.follow!(target_actor_or_uri)
  end

  # アンフォロー実行
  def unfollow!(target_actor_or_uri)
    follow_service = FollowService.new(self)
    follow_service.unfollow!(target_actor_or_uri)
  end

  private

  # プロフィール更新を検知
  def should_distribute_profile_update?
    return false unless local?

    # プロフィールに関連する属性が変更されたかチェック
    profile_attributes = %w[display_name note fields]
    saved_changes.keys.any? { |attr| profile_attributes.include?(attr) } ||
      saved_changes.key?('avatar') ||
      saved_changes.key?('header')
  end

  # プロフィール更新を配信
  def distribute_profile_update
    SendProfileUpdateJob.perform_later(id)
  end
end
