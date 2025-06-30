# frozen_string_literal: true

class LinkPreview < ApplicationRecord
  validates :url, presence: true, uniqueness: true
  validates :title, length: { maximum: 255 }
  validates :description, length: { maximum: 500 }

  scope :recent, -> { order(created_at: :desc) }

  def self.fetch_or_create(url)
    return nil if url.blank?

    # 既存のプレビューがあるかチェック
    existing = find_by(url: url)
    return existing if existing&.fresh?

    # OGP情報を取得
    ogp_data = OgpFetcher.fetch(url)
    return nil unless ogp_data

    # 新規作成または更新
    if existing
      existing.update!(ogp_data)
      existing
    else
      create!(ogp_data)
    end
  rescue StandardError => e
    Rails.logger.warn "Failed to create link preview for #{url}: #{e.message}"
    nil
  end

  def fresh?
    created_at > 1.week.ago
  end
end
