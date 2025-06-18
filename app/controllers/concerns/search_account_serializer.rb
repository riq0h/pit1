# frozen_string_literal: true

module SearchAccountSerializer
  def serialized_account(actor)
    base_account_data(actor).merge(
      additional_account_data(actor)
    )
  end

  private

  def base_account_data(actor)
    {
      id: actor.id.to_s,
      username: actor.username,
      acct: actor.local? ? actor.username : actor.full_username,
      display_name: actor.display_name || actor.username,
      locked: actor.manually_approves_followers || false,
      bot: actor.actor_type == 'Service',
      discoverable: actor.discoverable || false,
      group: false,
      created_at: actor.created_at.iso8601,
      note: actor.summary || ''
    }
  end

  def additional_account_data(actor)
    {
      url: actor.public_url,
      avatar: actor.avatar_url || '/icon.png',
      avatar_static: actor.avatar_url || '/icon.png',
      header: actor.header_image_url || '/icon.png',
      header_static: actor.header_image_url || '/icon.png',
      followers_count: actor.followers_count || 0,
      following_count: actor.following_count || 0,
      statuses_count: actor.posts_count || 0,
      emojis: [],
      fields: []
    }
  end
end
