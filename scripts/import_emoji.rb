#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'

puts 'カスタム絵文字のインポートを開始します...'

# 絵文字ソースディレクトリ
source_dir = '/home/riq0h/Downloads/blobcatpnd_all_250309'
# Rails public/system ディレクトリ
system_dir = Rails.public_path.join('system', 'emojis')

# ディレクトリ作成
FileUtils.mkdir_p(system_dir)

# インポートする絵文字のリスト（代表的なものを選択）
emojis_to_import = [
  { file: 'ablobcatpnd_heart_happy.gif', shortcode: 'blobcat_heart', category: '感情' },
  { file: 'ablobcatpnd_dancing.gif', shortcode: 'blobcat_dance', category: '動作' },
  { file: 'ablobcatpnd_hugme.gif', shortcode: 'blobcat_hug', category: '動作' },
  { file: 'ablobcatpnd_yummy.gif', shortcode: 'blobcat_yummy', category: '食べ物' },
  { file: 'ablobcatpnd_nemunemu.gif', shortcode: 'blobcat_sleepy', category: '感情' },
  { file: 'ablobcatpnd_shy.gif', shortcode: 'blobcat_shy', category: '感情' },
  { file: 'blobcatpnd_muzukashi_thinking.png', shortcode: 'blobcat_think', category: '感情' },
  { file: 'blobcatpnd_osuwari.png', shortcode: 'blobcat_sit', category: '姿勢' },
  { file: 'ablobcatpnd_throw_kiss.gif', shortcode: 'blobcat_kiss', category: '動作' },
  { file: 'ablobcatpnd_cryalot.gif', shortcode: 'blobcat_cry', category: '感情' }
]

success_count = 0
error_count = 0

emojis_to_import.each do |emoji_data|
  result = process_emoji_import(emoji_data, source_dir)
  if result[:success]
    success_count += 1
  else
    error_count += 1
  end
end

def process_emoji_import(emoji_data, source_dir)
  source_file = File.join(source_dir, emoji_data[:file])

  unless File.exist?(source_file)
    puts "⚠️  ファイルが見つかりません: #{emoji_data[:file]}"
    return { success: false }
  end

  import_single_emoji(emoji_data, source_file)
rescue StandardError => e
  puts "❌ エラー: :#{emoji_data[:shortcode]}: - #{e.message}"
  { success: false }
end

def import_single_emoji(emoji_data, source_file)
  # 既存の絵文字をチェック
  existing_emoji = CustomEmoji.find_by(shortcode: emoji_data[:shortcode], domain: nil)
  if existing_emoji
    puts "⚠️  既に存在します: :#{emoji_data[:shortcode]}:"
    return { success: false }
  end

  emoji = create_emoji_with_image(emoji_data, source_file)

  if emoji.save
    puts "✅ 追加成功: :#{emoji_data[:shortcode]}: (#{emoji_data[:category]})"
    { success: true }
  else
    puts "❌ 追加失敗: :#{emoji_data[:shortcode]}: - #{emoji.errors.full_messages.join(', ')}"
    { success: false }
  end
end

def create_emoji_with_image(emoji_data, source_file)
  emoji = CustomEmoji.new(
    shortcode: emoji_data[:shortcode],
    visible_in_picker: true,
    category_id: emoji_data[:category],
    domain: nil
  )

  emoji.image.attach(
    io: File.open(source_file),
    filename: emoji_data[:file],
    content_type: "image/#{File.extname(emoji_data[:file]).delete('.')}"
  )

  emoji
end

puts ''
puts '=== インポート完了 ==='
puts "成功: #{success_count}個"
puts "失敗: #{error_count}個"
puts ''

if success_count.positive?
  puts '追加された絵文字は以下のように使用できます:'
  CustomEmoji.where(domain: nil).order(:created_at).last(success_count).each do |emoji|
    puts "  :#{emoji.shortcode}:"
  end
  puts ''
  puts "例: 投稿で ':blobcat_heart:' と入力すると絵文字が表示されます"
end
