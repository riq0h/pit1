#!/usr/bin/env ruby
# frozen_string_literal: true

# WebFingerから外部アクターを作成してフォローするスクリプト
# 使用例: rails runner bin/webfinger_follow.rb test5 username@example.com

require 'net/http'
require 'json'

def create_external_actor_from_webfinger(acct)
  username, domain = acct.split('@')

  # WebFingerでアカウント情報を取得
  webfinger_url = "https://#{domain}/.well-known/webfinger?resource=acct:#{acct}"
  uri = URI(webfinger_url)
  response = Net::HTTP.get_response(uri)

  unless response.is_a?(Net::HTTPSuccess)
    puts "WebFinger lookup failed for #{acct}: #{response.code} #{response.message}"
    return nil
  end

  webfinger_data = JSON.parse(response.body)

  # ActivityPub URLを取得
  activitypub_link = webfinger_data['links'].find do |link|
    link['rel'] == 'self' && link['type'] == 'application/activity+json'
  end

  unless activitypub_link
    puts "No ActivityPub URL found for #{acct}"
    return nil
  end

  activitypub_url = activitypub_link['href']

  # ActivityPubデータを取得
  uri = URI(activitypub_url)
  request = Net::HTTP::Get.new(uri)
  request['Accept'] = 'application/activity+json'
  response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(request) }

  unless response.is_a?(Net::HTTPSuccess)
    puts "ActivityPub lookup failed for #{acct}: #{response.code} #{response.message}"
    return nil
  end

  activitypub_data = JSON.parse(response.body)

  # Actorレコードを作成または更新
  actor = Actor.find_or_create_by(ap_id: activitypub_data['id']) do |a|
    a.username = activitypub_data['preferredUsername'] || username
    a.domain = domain
    a.display_name = activitypub_data['name']
    a.summary = activitypub_data['summary']
    a.inbox_url = activitypub_data['inbox']
    a.outbox_url = activitypub_data['outbox']
    a.followers_url = activitypub_data['followers']
    a.following_url = activitypub_data['following']
    a.public_key = activitypub_data.dig('publicKey', 'publicKeyPem')
    a.local = false
    a.raw_data = activitypub_data.to_json
  end

  if actor.persisted?
    puts "Actor created/updated: ID=#{actor.id}, username=#{actor.username}@#{actor.domain}"
    actor
  else
    puts "Failed to create actor: #{actor.errors.full_messages.join(', ')}"
    nil
  end
rescue StandardError => e
  puts "Error creating external actor for #{acct}: #{e.message}"
  nil
end

def follow_actor(follower_username, target_actor)
  follower = Actor.find_by(username: follower_username, local: true)
  unless follower
    puts "Local actor #{follower_username} not found"
    return false
  end

  # 既存のフォロー関係をチェック
  existing_follow = Follow.find_by(actor: follower, target_actor: target_actor)
  if existing_follow
    puts "Already following #{target_actor.username}@#{target_actor.domain} (accepted: #{existing_follow.accepted?})"
    return existing_follow
  end

  # フォローサービスを使用
  follow_service = FollowService.new(follower)
  follow = follow_service.follow!(target_actor)

  if follow
    puts "Follow request created: #{follower.username} -> #{target_actor.username}@#{target_actor.domain}"
    follow
  else
    puts 'Failed to create follow request'
    false
  end
rescue StandardError => e
  puts "Error following actor: #{e.message}"
  false
end

# メイン処理
if ARGV.length >= 2
  follower_username = ARGV[0]
  target_acct = ARGV[1]

  puts "Creating external actor for #{target_acct}..."
  target_actor = create_external_actor_from_webfinger(target_acct)

  if target_actor
    puts "Following #{target_acct} from #{follower_username}..."
    follow_result = follow_actor(follower_username, target_actor)

    if follow_result
      puts '✓ Follow process completed'
    else
      puts '✗ Follow process failed'
    end
  else
    puts '✗ Could not create external actor'
  end
else
  puts 'Usage: rails runner bin/webfinger_follow.rb <local_username> <target_username@domain>'
  puts 'Example: rails runner bin/webfinger_follow.rb test5 username@example.com'
end
