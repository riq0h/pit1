# frozen_string_literal: true

class QuotePost < ApplicationRecord
  belongs_to :actor
  belongs_to :object, class_name: 'ActivityPubObject', foreign_key: :object_id, primary_key: :id
  belongs_to :quoted_object, class_name: 'ActivityPubObject', foreign_key: :quoted_object_id, primary_key: :id

  validates :object_id, uniqueness: { scope: :quoted_object_id }
  validates :visibility, inclusion: { in: ActivityPubObject::VISIBILITY_LEVELS }
  validates :ap_id, presence: true, uniqueness: true

  scope :recent, -> { order(created_at: :desc) }
  scope :shallow, -> { where(shallow_quote: true) }
  scope :deep, -> { where(shallow_quote: false) }
  scope :public_quotes, -> { where(visibility: 'public') }

  # Shallow Quote: 引用元のポストを単純に再共有（追加テキストなし）
  def shallow_quote?
    shallow_quote
  end

  # Deep Quote: 引用元のポストに追加のコメント/テキストを付けて共有
  def deep_quote?
    !shallow_quote
  end

  def local?
    actor.local?
  end

  def remote?
    !local?
  end

  # ActivityPub JSON-LD representation
  def to_activitypub
    {
      '@context' => 'https://www.w3.org/ns/activitystreams',
      'id' => ap_id,
      'type' => 'Quote',
      'actor' => actor.ap_id,
      'object' => quoted_object.ap_id,
      'published' => created_at.iso8601,
      'to' => build_audience_list(:to),
      'cc' => build_audience_list(:cc),
      'quoteUrl' => quoted_object.ap_id,  # FEP-e232 compatibility
      '_misskey_quote' => quoted_object.ap_id  # Misskey compatibility
    }.tap do |json|
      json['content'] = quote_text if deep_quote? && quote_text.present?
    end.compact
  end

  private

  def build_audience_list(type)
    case visibility
    when 'public'
      build_public_audience_list(type)
    when 'unlisted'
      build_unlisted_audience_list(type)
    when 'private'
      build_followers_audience_list(type)
    when 'direct'
      build_direct_audience_list(type)
    else
      []
    end
  end

  def build_public_audience_list(type)
    case type
    when :to
      ['https://www.w3.org/ns/activitystreams#Public']
    when :cc
      [actor.followers_url]
    end
  end

  def build_unlisted_audience_list(type)
    case type
    when :to
      [actor.followers_url]
    when :cc
      ['https://www.w3.org/ns/activitystreams#Public']
    end
  end

  def build_followers_audience_list(type)
    case type
    when :to
      [actor.followers_url]
    when :cc
      []
    end
  end

  def build_direct_audience_list(type)
    case type
    when :to
      [quoted_object.actor.ap_id]  # Quote the original author in DM
    when :cc
      []
    end
  end
end