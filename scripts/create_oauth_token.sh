#!/bin/bash

# Letter ActivityPub Instance - OAuth Token Generation Script
# OAuthアクセストークンを生成して API 利用を可能にします

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

print_header "Letter ActivityPub OAuth トークン生成"
echo ""

print_info "このスクリプトはAPIアクセス用のOAuthトークンを生成します"
echo ""

# ユーザ名の入力
while true; do
    read -p "ユーザ名を入力してください: " username
    
    if [[ -z "$username" ]]; then
        print_error "ユーザ名は必須です"
        continue
    fi
    
    # Basic username validation
    if [[ ! "$username" =~ ^[a-zA-Z0-9_]+$ ]]; then
        print_error "ユーザ名は英数字とアンダースコアのみ使用できます"
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
        print_error "ユーザ '$username' が見つかりません"
        print_info "既存のローカルユーザを確認してください"
        echo ""
        print_info "既存のローカルユーザ一覧:"
        local_users=$(run_with_env "
        actors = Actor.where(local: true)
        if actors.any?
          actors.each { |a| puts \"  - #{a.username} (#{a.display_name || 'No display name'})\" }
        else
          puts '  ローカルユーザがありません。まず ./scripts/manage_accounts.sh でアカウントを作成してください。'
        end
        ")
        echo "$local_users"
        echo ""
        continue
    fi
    
    break
done

echo ""
print_info "ユーザ '$username' 用のOAuthトークンを生成中..."

# トークン生成スクリプトの実行
cat > tmp_create_token.rb << EOF
#!/usr/bin/env ruby

username = "$username"

begin
  # Find user
  actor = Actor.find_by(username: username, local: true)
  unless actor
    puts "error|ユーザ '\#{username}' が見つかりません"
    exit 1
  end

  # Create or find OAuth application
  app = Doorkeeper::Application.find_or_create_by(uid: "letter_client_\#{username}") do |a|
    a.name = "Letter API Client (\#{username})"
    a.secret = SecureRandom.hex(32)
    a.redirect_uri = "urn:ietf:wg:oauth:2.0:oob"
    a.scopes = "read write follow"
  end

  # Create access token
  token = Doorkeeper::AccessToken.create!(
    application: app,
    resource_owner_id: actor.id,
    scopes: "read write follow"
  )

  puts "success|OAuth トークンが正常に作成されました！"
  puts "app_name|\#{app.name}"
  puts "client_id|\#{app.uid}"
  puts "client_secret|\#{app.secret}"
  puts "token|\#{token.token}"
  puts "scopes|\#{token.scopes}"
  puts "username|\#{actor.username}"
  puts "domain|\#{ENV['ACTIVITYPUB_DOMAIN']}"
  puts "protocol|\#{ENV['ACTIVITYPUB_PROTOCOL']}"

rescue => e
  puts "error|トークン作成に失敗しました: \#{e.message}"
  exit 1
end
EOF

# スクリプト実行
result=$(run_with_env "$(cat tmp_create_token.rb)")

# 一時ファイルの削除
rm -f tmp_create_token.rb

echo ""

# Parse results
status=$(echo "$result" | grep "^success\|^error" | head -1 | cut -d'|' -f1)

if [[ "$status" == "success" ]]; then
    message=$(echo "$result" | grep "^success" | cut -d'|' -f2)
    app_name=$(echo "$result" | grep "^app_name" | cut -d'|' -f2)
    client_id=$(echo "$result" | grep "^client_id" | cut -d'|' -f2)
    client_secret=$(echo "$result" | grep "^client_secret" | cut -d'|' -f2)
    token=$(echo "$result" | grep "^token" | cut -d'|' -f2)
    scopes=$(echo "$result" | grep "^scopes" | cut -d'|' -f2)
    username=$(echo "$result" | grep "^username" | cut -d'|' -f2)
    domain=$(echo "$result" | grep "^domain" | cut -d'|' -f2)
    protocol=$(echo "$result" | grep "^protocol" | cut -d'|' -f2)
    
    print_success "$message"
    echo ""
    print_info "アプリケーション詳細:"
    echo "  名前: $app_name"
    echo "  クライアントID: $client_id"
    echo "  クライアントシークレット: $client_secret"
    echo ""
    print_info "アクセストークン:"
    echo "  トークン: $token"
    echo "  スコープ: $scopes"
    echo "  ユーザ: $username"
    echo ""
    print_info "API使用例:"
    echo "  # アカウント情報確認"
    echo "  curl -H \"Authorization: Bearer $token\" \\"
    echo "       \"$protocol://$domain/api/v1/accounts/verify_credentials\""
    echo ""
    echo "  # 投稿作成"
    echo "  curl -X POST \\"
    echo "       -H \"Authorization: Bearer $token\" \\"
    echo "       -H \"Content-Type: application/json\" \\"
    echo "       -d '{\"status\":\"Hello from API!\",\"visibility\":\"public\"}' \\"
    echo "       \"$protocol://$domain/api/v1/statuses\""
    echo ""
    echo "  # アバター設定"
    echo "  curl -X PATCH \\"
    echo "       -H \"Authorization: Bearer $token\" \\"
    echo "       -F \"avatar=@/path/to/image.png\" \\"
    echo "       \"$protocol://$domain/api/v1/accounts/update_credentials\""
    
else
    message=$(echo "$result" | grep "^error" | cut -d'|' -f2)
    print_error "$message"
    exit 1
fi

echo ""
print_header "OAuth トークン生成完了"