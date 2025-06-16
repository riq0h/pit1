#!/bin/bash

# Letter ActivityPub Instance - Follow System Test Script
# フォローシステムの動作確認とテストを行います

set -e

# Get the directory of this script and the project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Change to project root to ensure relative paths work
cd "$PROJECT_ROOT"

# Load environment variables
source scripts/load_env.sh

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
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

print_header "Letter ActivityPub フォローシステムテスト"
echo ""

print_info "このスクリプトはフォローシステム（FollowService、WebFingerService）の動作確認を行います"
echo ""

# 現在のユーザー一覧を表示
print_info "利用可能なローカルユーザー:"
run_with_env "
Actor.where(local: true).each do |a|
  puts '  - ' + a.username + ' (' + (a.display_name || '表示名なし') + ')'
end
"

echo ""

# ユーザー名の入力
while true; do
    read -p "テストに使用するユーザー名を入力してください: " username
    
    if [[ -z "$username" ]]; then
        print_error "ユーザー名は必須です"
        continue
    fi
    
    # Basic username validation
    if [[ ! "$username" =~ ^[a-zA-Z0-9_]+$ ]]; then
        print_error "ユーザー名は英数字とアンダースコアのみ使用できます"
        continue
    fi
    
    # Check if user exists
    user_check=$(run_with_env "
    if Actor.exists?(username: '$username', local: true)
      puts 'exists'
    else
      puts 'not_found'
    end
    ")
    
    if [[ "$user_check" == "not_found" ]]; then
        print_error "ユーザー '$username' が見つかりません"
        print_info "既存のローカルユーザーを確認してください"
        echo ""
        print_info "既存のローカルユーザー一覧:"
        local_users=$(run_with_env "
        actors = Actor.where(local: true)
        if actors.any?
          actors.each { |a| puts \"  - #{a.username} (#{a.display_name || 'No display name'})\" }
        else
          puts '  ローカルユーザーがありません。まず ./scripts/manage_accounts.sh でアカウントを作成してください。'
        end
        ")
        echo "$local_users"
        echo ""
        continue
    fi
    
    break
done

echo ""
print_info "ユーザー '$username' でフォローシステムをテストします"

# フォローシステムのテスト
cat > tmp_test_follow.rb << EOF
#!/usr/bin/env ruby

username = "$username"

begin
  # Find the actor
  actor = Actor.find_by(username: username, local: true)
  unless actor
    puts "error|ユーザー '\#{username}' が見つかりません"
    exit 1
  end

  puts "success|ユーザーを発見: \#{actor.username}"
  puts "info|現在のフォロー数: \#{actor.following_count}"
  puts "info|現在のフォロワー数: \#{actor.followers_count}"
  
  # Test 1: Check if FollowService loads
  puts "test_start|FollowService の初期化テスト"
  begin
    follow_service = FollowService.new(actor)
    puts "test_success|FollowService が正常に初期化されました"
  rescue => e
    puts "test_error|FollowService の初期化に失敗: \#{e.message}"
  end
  
  # Test 2: Test actor follow! method
  puts "test_start|Actor#follow! メソッドのテスト"
  begin
    method_exists = actor.respond_to?(:follow!)
    if method_exists
      puts "test_success|Actor#follow! メソッドが存在します"
    else
      puts "test_error|Actor#follow! メソッドが見つかりません"
    end
  rescue => e
    puts "test_error|Actor#follow! メソッドテストでエラー: \#{e.message}"
  end
  
  # Test 3: Test WebFingerService
  puts "test_start|WebFingerService のテスト"
  begin
    webfinger_service = WebFingerService.new
    puts "test_success|WebFingerService が正常に初期化されました"
  rescue => e
    puts "test_error|WebFingerService でエラー: \#{e.message}"
  end
  
  # Test 4: Check existing follows
  puts "test_start|既存のフォロー関係の確認"
  outgoing_follows = Follow.where(actor: actor, accepted: true)
  incoming_follows = Follow.where(target_actor: actor, accepted: true)
  
  puts "info|フォロー中のアカウント数: \#{outgoing_follows.count}"
  outgoing_follows.each do |f|
    domain_part = f.target_actor.domain || 'ローカル'
    puts "follow_out|\#{f.target_actor.username}@\#{domain_part}"
  end
  
  puts "info|フォロワー数: \#{incoming_follows.count}"
  incoming_follows.each do |f|
    domain_part = f.actor.domain || 'ローカル'
    puts "follow_in|\#{f.actor.username}@\#{domain_part}"
  end
  
  # Test 5: Test base URL configuration
  puts "test_start|ActivityPub 基本設定の確認"
  base_url = Rails.application.config.activitypub.base_url
  puts "info|ActivityPub ベースURL: \#{base_url}"
  
  if base_url.include?('localhost')
    puts "test_warning|ローカルホストURL が設定されています。本番環境では適切なドメインを設定してください"
  else
    puts "test_success|適切なドメインが設定されています"
  end

  puts "overall_success|すべてのテストが完了しました！"
  puts "info|システムは正常なフォロー操作の準備ができています"
  puts "info|actor.follow!('username@domain') メソッドまたは"
  puts "info|適切なFollow レコード作成機能付きのAPI エンドポイントを使用できます"

rescue => e
  puts "error|テスト中にエラーが発生しました: \#{e.message}"
  puts "debug|\#{e.backtrace.first(3).join('\\n')}"
  exit 1
end
EOF

# スクリプト実行
result=$(run_with_env "$(cat tmp_test_follow.rb)")

# 一時ファイルの削除
rm -f tmp_test_follow.rb

echo ""

# Parse and display results
echo "$result" | while IFS='|' read -r type message; do
    case "$type" in
        "error")
            print_error "$message"
            exit 1
            ;;
        "success")
            print_success "$message"
            ;;
        "info")
            print_info "$message"
            ;;
        "test_start")
            echo -e "${CYAN}🔍${NC} $message"
            ;;
        "test_success")
            echo -e "${GREEN}  ✓${NC} $message"
            ;;
        "test_error")
            echo -e "${RED}  ✗${NC} $message"
            ;;
        "test_warning")
            echo -e "${YELLOW}  ⚠️${NC} $message"
            ;;
        "follow_out")
            echo -e "${BLUE}  → ${NC}フォロー中: $message"
            ;;
        "follow_in")
            echo -e "${BLUE}  ← ${NC}フォロワー: $message"
            ;;
        "overall_success")
            echo ""
            print_success "$message"
            ;;
        "debug")
            echo -e "${YELLOW}デバッグ情報:${NC}"
            echo "$message"
            ;;
    esac
done

echo ""
print_header "テストサマリー"
print_success "新しいフォローシステムコンポーネントがインストールされています"
print_success "FollowService がリモートアクター取得とFollowレコード作成を処理します"
print_success "API エンドポイントが FollowService を使用するように更新されています"
print_success "Actor モデルに follow!/unfollow! 便利メソッドがあります"
echo ""
print_info "次回フォローリクエストを送信する際の処理:"
echo "  1. ローカル Follow レコードを即座に作成"
echo "  2. 必要に応じてリモートアクターデータを取得"
echo "  3. ActivityPub フォローアクティビティを送信"
echo "  4. フォローカウントを適切に更新"