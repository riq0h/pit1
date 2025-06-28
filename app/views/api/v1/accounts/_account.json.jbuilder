# frozen_string_literal: true

json.id account.id.to_s
json.username account.username
json.acct account.acct
json.display_name account.display_name || ''
json.locked account.manually_approves_followers
json.bot false
json.discoverable account.discoverable
json.group false
json.created_at account.created_at.iso8601
json.note account.note || ''
json.url account.public_url
json.avatar account.avatar_url || '/system/accounts/avatars/missing.png'
json.avatar_static account.avatar_url || '/system/accounts/avatars/missing.png'
json.header account.header_image_url || '/system/accounts/headers/missing.png'
json.header_static account.header_image_url || '/system/accounts/headers/missing.png'
json.followers_count account.followers_count || 0
json.following_count account.following_count || 0
json.statuses_count account.posts_count || 0
json.last_status_at account.objects.where(object_type: 'Note').maximum(:published_at)&.to_date&.iso8601

# Custom emojis - プロフィールで使用されている絵文字
json.emojis []

# Profile fields - プロフィールリンク
if account.fields.present?
  begin
    fields_data = JSON.parse(account.fields)
    json.fields fields_data do |field|
      json.name field['name']
      json.value field['value']
      json.verified_at nil
    end
  rescue JSON::ParserError
    json.fields []
  end
else
  json.fields []
end

# Moved account info (for account migrations)
json.moved nil

# Suspended flag
json.suspended false

# Limited flag
json.limited false
