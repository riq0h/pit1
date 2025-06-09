# frozen_string_literal: true

class WellKnownController < ApplicationController
  skip_before_action :verify_authenticity_token

  # GET /.well-known/webfinger
  # RFC 7033 WebFinger実装
  def webfinger
    resource = params[:resource]

    return render_webfinger_error('Missing resource parameter') if resource.blank?

    actor = find_actor_by_resource(resource)

    return render_webfinger_error('Actor not found') unless actor

    render json: build_webfinger_response(actor),
           content_type: 'application/jrd+json; charset=utf-8'
  end

  # GET /.well-known/host-meta
  # RFC 6415 Host Metadata実装
  def host_meta
    render xml: build_host_meta_response,
           content_type: 'application/xrd+xml; charset=utf-8'
  end

  # GET /.well-known/nodeinfo
  # NodeInfo Discovery実装
  def nodeinfo
    render json: build_nodeinfo_discovery_response,
           content_type: 'application/json; charset=utf-8'
  end

  private

  def find_actor_by_resource(resource)
    # acct:username@domain 形式の解析
    if resource.start_with?('acct:')
      account_identifier = resource.sub('acct:', '')
      username, domain = account_identifier.split('@')

      # ローカルドメインかチェック
      local_domain = Rails.application.config.activitypub.domain
      return nil unless domain == local_domain

      Actor.find_by(username: username, local: true)
    elsif resource.start_with?('http')
      # HTTP(S) URL形式での検索
      Actor.find_by(ap_id: resource, local: true)
    end
  end

  def build_webfinger_response(actor)
    {
      subject: actor.webfinger_subject,
      aliases: [
        actor.ap_id,
        actor.public_url
      ].compact,
      links: [
        {
          rel: 'self',
          type: 'application/activity+json',
          href: actor.ap_id
        },
        {
          rel: 'http://webfinger.net/rel/profile-page',
          type: 'text/html',
          href: actor.public_url || actor.ap_id
        },
        {
          rel: 'http://ostatus.org/schema/1.0/subscribe',
          template: "#{base_url}/authorize_interaction?uri={uri}"
        }
      ]
    }
  end

  def build_host_meta_response
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <XRD xmlns="http://docs.oasis-open.org/ns/xri/xrd-1.0">
        <Link rel="lrdd" template="#{base_url}/.well-known/webfinger?resource={uri}"/>
      </XRD>
    XML
  end

  def build_nodeinfo_discovery_response
    {
      links: [
        {
          rel: 'http://nodeinfo.diaspora.software/ns/schema/2.1',
          href: "#{base_url}/nodeinfo/2.1"
        }
      ]
    }
  end

  def base_url
    @base_url ||= begin
      domain = Rails.application.config.activitypub.domain
      scheme = Rails.env.production? ? 'https' : 'http'
      "#{scheme}://#{domain}"
    end
  end

  def render_webfinger_error(message)
    render json: { error: message },
           status: :not_found,
           content_type: 'application/jrd+json; charset=utf-8'
  end
end
