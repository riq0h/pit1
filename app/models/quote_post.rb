# frozen_string_literal: true

class QuotePost < ApplicationRecord
  include RemoteLocalHelper

  belongs_to :actor
  belongs_to :object, class_name: 'ActivityPubObject', primary_key: :id
  belongs_to :quoted_object, class_name: 'ActivityPubObject', primary_key: :id

  validates :object_id, uniqueness: { scope: :quoted_object_id }
  validates :visibility, inclusion: { in: ActivityPubObject::VISIBILITY_LEVELS }
  validates :ap_id, presence: true, uniqueness: true

  # コールバック
  after_create :notify_quoted_status_author

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

  delegate :local?, to: :actor

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
      'quoteUrl' => quoted_object.ap_id, # FEP-e232互換性
      '_misskey_quote' => quoted_object.ap_id # Misskey互換性
    }.tap do |json|
      json['content'] = quote_text if deep_quote? && quote_text.present?
    end.compact
  end

  private

  def build_audience_list(type)
    ActivityBuilders::AudienceBuilder.new(self).build(type)
  end

  def notify_quoted_status_author
    # 自分自身の投稿を引用した場合は通知しない
    return if quoted_object.actor == actor

    # 引用された投稿の作者に通知を送信
    Notification.create_quote_notification(self, quoted_object)
  rescue StandardError => e
    Rails.logger.error "Failed to create quote notification: #{e.message}"
  end
end
