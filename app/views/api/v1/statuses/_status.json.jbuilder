# frozen_string_literal: true

json.id status.id.to_s
json.created_at status.published_at.iso8601
json.in_reply_to_id nil
json.in_reply_to_account_id nil
json.sensitive status.sensitive?
json.spoiler_text status.summary || ''
json.visibility status.visibility
json.language status.language || 'ja'
json.uri status.ap_id
json.url status.ap_id
json.replies_count status.replies_count || 0
json.reblogs_count status.reblogs_count || 0
json.favourites_count status.favourites_count || 0
json.edited_at status.edited_at&.iso8601

# Content - HTMLサニタイズ済み
json.content status.content || ''

# アカウント情報
json.account do
  json.id status.actor.id.to_s
  json.username status.actor.username
  json.acct status.actor.local? ? status.actor.username : "#{status.actor.username}@#{status.actor.domain}"
  json.display_name status.actor.display_name || ''
  json.locked status.actor.manually_approves_followers || false
  json.bot false
  json.discoverable status.actor.discoverable || false
  json.group false
  json.created_at status.actor.created_at.iso8601
  json.note status.actor.note || ''
  json.url status.actor.public_url
  json.avatar status.actor.avatar_url || '/system/accounts/avatars/missing.png'
  json.avatar_static status.actor.avatar_url || '/system/accounts/avatars/missing.png'
  json.header status.actor.header_image_url || '/system/accounts/headers/missing.png'
  json.header_static status.actor.header_image_url || '/system/accounts/headers/missing.png'
  json.followers_count status.actor.followers_count || 0
  json.following_count status.actor.following_count || 0
  json.statuses_count status.actor.posts_count || 0
  json.last_status_at nil
  json.emojis []
  json.fields []
end

# 添付
json.media_attachments status.media_attachments do |attachment|
  json.id attachment.id.to_s
  json.type attachment.media_type || 'unknown'
  json.url attachment.remote_url.presence || (attachment.respond_to?(:url) ? attachment.url : '')
  json.preview_url attachment.remote_url.presence || (attachment.respond_to?(:url) ? attachment.url : '')
  json.remote_url attachment.remote_url
  json.preview_remote_url attachment.remote_url
  json.text_url nil
  json.meta do
    if attachment.width.present? && attachment.height.present? && attachment.width > 0 && attachment.height > 0
      json.original do
        json.width attachment.width
        json.height attachment.height
        json.size "#{attachment.width}x#{attachment.height}"
        json.aspect attachment.width.to_f / attachment.height
      end
    end
  end
  json.description attachment.description || ''
  json.blurhash nil
end

# メンション
json.mentions status.mentions.select { |m| m.actor.present? } do |mention|
  json.id mention.actor.id.to_s
  json.username mention.actor.username
  json.url mention.actor.public_url
  json.acct mention.actor.acct
end

# ハッシュタグ
json.tags status.tags do |tag|
  json.name tag.name
  json.url "#{Rails.application.config.activitypub.base_url}/tags/#{tag.name}"
end

# カスタム絵文字
json.emojis []

# 投票が存在する場合
if status.poll.present?
  json.poll do
    json.id status.poll.id.to_s
    json.expires_at status.poll.expires_at&.iso8601
    json.expired status.poll.expired?
    json.multiple status.poll.multiple
    json.votes_count status.poll.votes_count || 0
    json.voters_count status.poll.voters_count || 0
    json.voted false
    json.own_votes []
    json.options status.poll.options do |option|
      json.title option['title']
      json.votes_count 0
    end
    json.emojis []
  end
else
  json.poll nil
end

# OAuth
json.application do
  json.name 'letter'
  json.website nil
end

# 引用投稿
if status.quoted?
  quote_post = status.quote_posts.first
  if quote_post&.quoted_object
    json.quote do
      json.id quote_post.quoted_object.id.to_s
      json.content quote_post.quoted_object.content || ''
      json.created_at quote_post.quoted_object.published_at.iso8601
      json.account do
        json.id quote_post.quoted_object.actor.id.to_s
        json.username quote_post.quoted_object.actor.username
        json.display_name quote_post.quoted_object.actor.display_name || ''
      end
    end
  else
    json.quote nil
  end
else
  json.quote nil
end

# ログインユーザの操作状況
json.favourited false
json.reblogged false
json.muted false
json.bookmarked false
json.pinned false