#!/usr/bin/env ruby
# frozen_string_literal: true

puts '絵文字投稿テストを開始します...'

# テスト投稿を作成
tester = Actor.find_by(username: 'tester', local: true)
if tester
  content = 'カスタム絵文字のテストです :blobcat_heart: 楽しい :blobcat_dance: ですね :blobcat_shy:'

  post = tester.objects.create!(
    object_type: 'Note',
    content: content,
    published_at: Time.current,
    local: true,
    ap_id: "https://#{ENV.fetch('ACTIVITYPUB_DOMAIN', nil)}/users/tester/posts/#{SecureRandom.uuid}",
    visibility: 'public'
  )

  puts "テスト投稿を作成しました: #{post.id}"
  puts "内容: #{post.content}"

  # 絵文字パース結果を表示
  parser = EmojiParser.new(post.content)
  puts "パース後のHTML: #{parser.parse}"
  puts "使用された絵文字: #{parser.emojis_used.map(&:shortcode).join(', ')}"

  # API経由でのレスポンス確認
  puts ''
  puts '=== API レスポンステスト ==='

  # StatusSerializerを使用してAPIレスポンスをテスト
  require_relative '../app/controllers/concerns/status_serializer'

  class TestSerializer
    include StatusSerializer

    def current_user
      nil
    end

    def serialized_account(actor)
      { id: actor.id.to_s, username: actor.username }
    end

    def serialized_media_attachments(_status)
      []
    end

    def serialized_mentions(_status)
      []
    end

    def serialized_tags(_status)
      []
    end

    def replies_count(_status)
      0
    end

    def favourited_by_current_user?(_status)
      false
    end

    def reblogged_by_current_user?(_status)
      false
    end

    def in_reply_to_id(_status)
      nil
    end

    def in_reply_to_account_id(_status)
      nil
    end
  end

  serializer = TestSerializer.new

  # シリアライズされたデータを取得
  serialized_data = serializer.send(:content_data, post)
  emoji_data = serializer.send(:serialized_emojis, post)

  puts "APIレスポンスのcontent: #{serialized_data[:content]}"
  puts "絵文字データ数: #{emoji_data.length}"
  emoji_data.each do |emoji|
    puts "  - #{emoji[:shortcode]}: #{emoji[:url] || '画像URLなし'}"
  end

else
  puts 'testerユーザが見つかりません'
end
