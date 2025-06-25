# frozen_string_literal: true

module Search
  class RemoteResolverService
    def initialize
      @web_finger_service = WebFingerService.new
    end

    def resolve_remote_account(query)
      return nil unless account_query?(query)

      begin
        actor_data = @web_finger_service.fetch_actor_data(query)
        return nil unless actor_data

        create_actor_from_data(actor_data)
      rescue StandardError => e
        Rails.logger.warn "リモートアカウント解決エラー: #{e.message}"
        nil
      end
    end

    def resolve_remote_status(url)
      return nil unless url_query?(url)

      begin
        response = fetch_activitypub_object(url)
        return nil unless response

        activitypub_id = response['id']
        return nil unless activitypub_id

        existing_object = ActivityPubObject.find_by(ap_id: activitypub_id)
        return existing_object if existing_object

        create_remote_object(response)
      rescue StandardError => e
        Rails.logger.warn "リモート投稿解決エラー: #{e.message}"
        nil
      end
    end

    def resolve_remote_status_for_pinned(url)
      return nil unless url_query?(url)

      begin
        response = fetch_activitypub_object(url)
        return nil unless response

        activitypub_id = response['id']
        return nil unless activitypub_id

        existing_object = ActivityPubObject.find_by(ap_id: activitypub_id)
        return existing_object if existing_object

        create_remote_object(response, is_pinned_only: true)
      rescue StandardError => e
        Rails.logger.warn "ピン留め投稿解決エラー: #{e.message}"
        nil
      end
    end

    private

    def create_actor_from_data(data)
      return nil unless data['type'] == 'Person'

      existing_actor = Actor.find_by(ap_id: data['id'])
      return existing_actor if existing_actor

      # ActorFetcherを使用してemoji処理も含めて作成
      actor_fetcher = ActorFetcher.new
      actor_fetcher.create_actor_from_data(data['id'], data)
    rescue StandardError => e
      Rails.logger.error "アクター作成エラー: #{e.message}"
      nil
    end

    def create_actor_record(data, username, domain)
      Actor.create!(
        username: username,
        domain: domain,
        display_name: data['name'],
        note: data['summary'],
        ap_id: data['id'],
        inbox_url: data['inbox'],
        outbox_url: data['outbox'],
        followers_url: data['followers'],
        following_url: data['following'],
        featured_url: data['featured'],
        public_key: data.dig('publicKey', 'publicKeyPem'),
        local: false,
        locked: data['manuallyApprovesFollowers'] || false,
        bot: data['type'] == 'Service',
        discoverable: data['discoverable'] || false,
        raw_data: data.to_json,
        fields: extract_fields_from_attachments(data).to_json,
        actor_type: data['type']
      )
    end

    def fetch_activitypub_object(url)
      uri = URI(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'

      request = Net::HTTP::Get.new(uri)
      request['Accept'] = 'application/activity+json, application/ld+json'
      request['User-Agent'] = 'Letter/1.0'

      response = http.request(request)
      return nil unless response.code == '200'

      JSON.parse(response.body)
    end

    def create_remote_object(data, is_pinned_only: false)
      return nil unless data['type'] == 'Note'

      actor = resolve_actor_for_object(data)
      return nil unless actor

      remote_id = Letter::Snowflake.generate
      create_activity_pub_object(data, actor, remote_id, is_pinned_only: is_pinned_only)
    rescue StandardError => e
      Rails.logger.error "リモートオブジェクト作成エラー: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      nil
    end

    def resolve_actor_for_object(data)
      actor_uri = data['attributedTo']
      actor = Actor.find_by(ap_id: actor_uri)

      unless actor
        actor_fetcher = ActorFetcher.new
        actor = actor_fetcher.fetch_and_create(actor_uri)
      end

      actor
    end

    def create_activity_pub_object(data, actor, remote_id, is_pinned_only: false)
      object = ActivityPubObject.create!(
        id: remote_id,
        ap_id: data['id'],
        object_type: data['type'],
        actor: actor,
        content: data['content'],
        content_plaintext: strip_html(data['content']),
        summary: data['summary'],
        published_at: Time.zone.parse(data['published']),
        visibility: determine_visibility(data),
        raw_data: data.to_json,
        local: false,
        is_pinned_only: is_pinned_only
      )

      handle_media_attachments(object, data)
      object
    end

    def determine_visibility(data)
      to_array = Array(data['to'])
      cc_array = Array(data['cc'])

      if to_array.include?('https://www.w3.org/ns/activitystreams#Public')
        'public'
      elsif cc_array.include?('https://www.w3.org/ns/activitystreams#Public')
        'unlisted'
      else
        'private'
      end
    end

    def strip_html(content)
      return '' if content.blank?

      ActionController::Base.helpers.strip_tags(content)
    end

    def handle_media_attachments(object, object_data)
      attachments = object_data['attachment']
      return unless attachments.is_a?(Array) && attachments.any?

      attachments.each do |attachment|
        next unless attachment.is_a?(Hash) && attachment['type'] == 'Document'

        create_media_attachment(object, attachment)
      end
    end

    def create_media_attachment(object, attachment_data)
      url = attachment_data['url']
      file_name = extract_filename_from_url(url)
      media_type = determine_media_type_from_content_type(attachment_data['mediaType'])

      media_attrs = build_media_attachment_attributes(object, attachment_data, url, media_type, file_name)
      MediaAttachment.create!(media_attrs)
      Rails.logger.info "📎 Media attachment created for object #{object.id}: #{url}"
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.warn "⚠️ Failed to create media attachment: #{e.message}"
    end

    def build_media_attachment_attributes(object, attachment_data, url, media_type, file_name)
      {
        actor: object.actor,
        object: object,
        remote_url: url,
        content_type: attachment_data['mediaType'],
        media_type: media_type,
        file_name: file_name,
        file_size: 1,
        description: attachment_data['name'],
        width: attachment_data['width'],
        height: attachment_data['height'],
        blurhash: attachment_data['blurhash']
      }
    end

    def extract_filename_from_url(url)
      uri = URI.parse(url)
      filename = File.basename(uri.path)
      filename.presence || 'unknown_file'
    rescue URI::InvalidURIError
      'unknown_file'
    end

    def determine_media_type_from_content_type(content_type)
      return 'image' if content_type&.start_with?('image/')
      return 'video' if content_type&.start_with?('video/')
      return 'audio' if content_type&.start_with?('audio/')

      'document'
    end

    def extract_fields_from_attachments(actor_data)
      attachments = actor_data['attachment'] || []
      return [] unless attachments.is_a?(Array)

      attachments.filter_map do |attachment|
        next unless attachment.is_a?(Hash) && attachment['type'] == 'PropertyValue'

        {
          name: attachment['name'],
          value: attachment['value']
        }
      end
    end

    def account_query?(query)
      query.match?(/^@?[\w.-]+@[\w.-]+\.\w+$/) || query.start_with?('@')
    end

    def url_query?(query)
      query.match?(/^https?:\/\//)
    end
  end
end
