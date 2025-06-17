#!/bin/bash

# Letter ActivityPub Instance - Test Posts Generation Script
# 多言語テスト投稿データを生成します

set -e

# スクリプトのディレクトリとプロジェクトルートを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 相対パスが正しく動作するようプロジェクトルートに移動
cd "$PROJECT_ROOT"

# 環境変数を読み込み
source bin/load_env.sh

# 出力用の色設定
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# カラー出力用関数
print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

print_error() {
    echo -e "${RED}❌${NC} $1"
}

print_info() {
    echo -e "${CYAN}ℹ️${NC} $1"
}

print_header "Letter ActivityPub テスト投稿生成"
echo ""

print_info "このスクリプトは多言語のテスト投稿データを生成します"
print_info "英語20件、日本語20件、混在テキスト20件の計60件を作成します"
echo ""

# ユーザ名の入力
while true; do
    read -p "投稿を作成するユーザ名を入力してください: " username
    
    if [[ -z "$username" ]]; then
        print_error "ユーザ名は必須です"
        continue
    fi
    
    # 基本的なユーザ名バリデーション
    if [[ ! "$username" =~ ^[a-zA-Z0-9_]+$ ]]; then
        print_error "ユーザ名は英数字とアンダースコアのみ使用できます"
        continue
    fi
    
    # ユーザの存在確認
    user_check=$(run_with_env "
    if Actor.exists?(username: '$username', local: true)
      puts 'exists'
    else
      puts 'not_found'
    end
    ")
    
    if [[ "$user_check" == "not_found" ]]; then
        print_error "ユーザ '$username' が見つかりません"
        print_info "既存のローカルユーザを確認してください"
        echo ""
        print_info "既存のローカルユーザ一覧:"
        local_users=$(run_with_env "
        actors = Actor.where(local: true)
        if actors.any?
          actors.each { |a| puts \"  - #{a.username} (#{a.display_name || '表示名未設定'})\" }
        else
          puts '  ローカルユーザがありません。まず ./bin/manage_accounts.sh でアカウントを作成してください。'
        end
        ")
        echo "$local_users"
        echo ""
        continue
    fi
    
    break
done

echo ""
print_info "ユーザ '$username' 用のテスト投稿を作成中..."
print_info "ドメイン: $ACTIVITYPUB_DOMAIN"

# 投稿作成の実行
result=$(run_with_env "
begin
  # ユーザを検索
  actor = Actor.find_by(username: '$username', local: true)
  unless actor
    puts 'error|ユーザ \"$username\" が見つかりません'
    exit 1
  end

  puts 'info|投稿作成を開始します'

  # 英語投稿
  english_posts = [
    'Hello world! This is my first English test post on this ActivityPub instance.',
    'Testing the federation capabilities of this server. How does it work with other instances?',
    'Beautiful sunset today! The colors were absolutely amazing. #photography #nature',
    'Just finished reading an excellent book about distributed systems. Highly recommended!',
    'Working on some exciting new features for this ActivityPub implementation.',
    'Coffee is essential for debugging complex federation issues.',
    'The decentralized web is the future. No more platform lock-in!',
    'Exploring the technical details of WebFinger and ActivityPub protocols.',
    'Open source software enables amazing collaboration across the globe.',
    'Testing hashtags, mentions, and other ActivityPub features. #testing #activitypub',
    'This instance supports emoji reactions!',
    'The community here is growing every day. Welcome to all new users!',
    'Debugging federation can be challenging but very rewarding when it works.',
    'Looking forward to connecting with more instances in the fediverse.',
    'The beauty of ActivityPub is in its simplicity and extensibility.',
    'Building a better, more open social web, one commit at a time.',
    'Testing cross-instance communication and message delivery.',
    'Privacy and user control should be fundamental rights on the internet.',
    'This is test post number 19 with some random content for testing.',
    'Final English test post. Thank you for reading all of these!'
  ]

  # 日本語投稿
  japanese_posts = [
    'こんにちは世界！このActivityPubインスタンスでの初めての日本語投稿です。',
    'このサーバの連合機能をテストしています。他のインスタンスとうまく動作するでしょうか？',
    '今日の夕焼けはとても美しかったです！色が本当に素晴らしかった。#写真 #自然',
    '分散システムについての素晴らしい本を読み終えました。強くお勧めします！',
    'このActivityPub実装に新しいエキサイティングな機能を開発中です。',
    '複雑な連合問題をデバッグするには、コーヒーが欠かせません。',
    '分散ウェブこそが未来です。もうプラットフォームロックインはありません！',
    'WebFingerとActivityPubプロトコルの技術的詳細を探求しています。',
    'オープンソースソフトウェアは世界中での素晴らしいコラボレーションを可能にします。',
    'ハッシュタグ、メンション、その他のActivityPub機能をテストしています。#テスト #activitypub',
    'このインスタンスは絵文字リアクションをサポートしています！',
    'ここのコミュニティは日々成長しています。すべての新しいユーザを歓迎します！',
    '連合のデバッグは困難ですが、動作したときはとてもやりがいがあります。',
    'フェディバースでより多くのインスタンスと接続することを楽しみにしています。',
    'ActivityPubの美しさは、そのシンプルさと拡張性にあります。',
    'より良い、よりオープンなソーシャルウェブを、一つのコミットずつ構築しています。',
    'インスタンス間通信とメッセージ配信をテストしています。',
    'プライバシーとユーザコントロールは、インターネット上での基本的権利であるべきです。',
    'これはテスト用のランダムなコンテンツを含む19番目のテスト投稿です。',
    '最後の日本語テスト投稿です。これらすべてを読んでいただき、ありがとうございます！'
  ]

  # 混在言語投稿
  mixed_posts = [
    'Hello こんにちは! Testing mixed language support 多言語サポートのテスト',
    'Beautiful day today! 今日はいい天気ですね Perfect for coding コーディングに最適',
    'Coffee time コーヒータイム！Debugging bugs バグを修正中',
    'Open source オープンソース is amazing 素晴らしい！Community コミュニティ power',
    'ActivityPub rocks! ActivityPubは最高！ Federation 連合 working perfectly',
    'Good morning おはようございます！Ready for coding コーディングの準備完了',
    'Testing テスト in progress 進行中... Everything すべて looking good 良好',
    'Documentation ドキュメント is important 重要です。Always いつも keep it updated',
    'Lunch time ランチタイム！ Back to coding after meal 食事後にコーディング再開',
    'Weekend 週末 coding session セッション。Fun 楽しい and productive 生産的',
    'New feature 新機能 deployed デプロイ完了！Users ユーザ will love it きっと気に入る',
    'Debug デバッグ session セッション complete 完了。All tests すべてのテスト passed',
    'Community コミュニティ feedback フィードバック is valuable 貴重です。Keep it coming',
    'Late night 夜更かし coding コーディング session セッション。Almost done もうすぐ完了',
    'Morning coffee 朝のコーヒー and code コード。Perfect combination 完璧な組み合わせ',
    'Testing mixed content 混在コンテンツのテスト。Works perfectly 完璧に動作',
    'International 国際的 collaboration コラボレーション is beautiful 美しい',
    'Code review コードレビュー time タイム！Quality 品質 matters 重要',
    'Almost finished ほぼ完了 with testing テスト。Great results 素晴らしい結果',
    'Final mixed post 最後の混在投稿！Thank you ありがとうございます'
  ]

  def create_posts_category(posts, category, actor)
    puts \"info|作成中: #{posts.length}件の#{category}投稿\"
    success_count = 0
    
    posts.each_with_index do |content, index|
      begin
        # ActivityPubオブジェクトを直接データベースに作成
        # 注意: Snowflake IDはbefore_validationコールバックで自動生成されます
        object = ActivityPubObject.create!(
          actor: actor,
          object_type: 'Note',
          content: content,
          content_plaintext: content,
          published_at: Time.current,
          local: true,
          visibility: 'public'
        )
        
        puts \"post_success|#{index + 1}/#{posts.length}|作成成功\"
        success_count += 1
      rescue => e
        puts \"post_error|#{index + 1}/#{posts.length}|作成失敗: #{e.message}\"
      end
    end
    
    puts \"category_result|#{category}|#{success_count}/#{posts.length}件作成完了\"
    return success_count
  end

  # カテゴリ別投稿作成
  english_success = create_posts_category(english_posts, '英語', actor)
  japanese_success = create_posts_category(japanese_posts, '日本語', actor) 
  mixed_success = create_posts_category(mixed_posts, '混在言語', actor)

  total_success = english_success + japanese_success + mixed_success
  total_attempted = english_posts.length + japanese_posts.length + mixed_posts.length

  puts \"summary|英語投稿: #{english_success}/#{english_posts.length}\"
  puts \"summary|日本語投稿: #{japanese_success}/#{japanese_posts.length}\"
  puts \"summary|混在言語投稿: #{mixed_success}/#{mixed_posts.length}\"
  puts \"summary|合計: #{total_success}/#{total_attempted} 投稿が作成されました\"
  puts \"summary|成功率: #{(total_success.to_f / total_attempted * 100).round(1)}%\"

rescue => e
  puts \"error|投稿作成中にエラーが発生しました: #{e.message}\"
  exit 1
end
")

echo ""

# 結果を解析して表示
echo "$result" | while IFS='|' read -r type message details; do
    case "$type" in
        "error")
            print_error "$message"
            exit 1
            ;;
        "info")
            print_info "$message"
            ;;
        "post_success")
            echo -e "${GREEN}  ✓${NC} $message: $details"
            ;;
        "post_error")
            echo -e "${RED}  ✗${NC} $message: $details"
            ;;
        "category_result")
            print_success "$message: $details"
            ;;
        "summary")
            print_info "$message"
            ;;
    esac
done

echo ""
print_header "テスト投稿生成完了"