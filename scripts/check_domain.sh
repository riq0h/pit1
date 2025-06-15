#!/bin/bash

# Letter ActivityPub Instance - Domain Configuration Check Script
# ドメイン設定確認スクリプト

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

print_header "Letter ActivityPub ドメイン設定確認"

# Check .env file
if [ -f .env ]; then
    DOMAIN=$(grep "^ACTIVITYPUB_DOMAIN=" .env | cut -d'=' -f2)
    PROTOCOL=$(grep "^ACTIVITYPUB_PROTOCOL=" .env | cut -d'=' -f2)
    
    print_info "環境設定:"
    echo "  ドメイン: $DOMAIN"
    echo "  プロトコル: $PROTOCOL"
    echo "  ベースURL: $PROTOCOL://$DOMAIN"
else
    print_warning ".envファイルが見つかりません"
fi

# Check if server is running
if pgrep -f "rails server\|puma" > /dev/null; then
    print_success "サーバー状態: 動作中"
    
    # Get list of local users
    echo ""
    print_info "ローカルユーザー:"
    LOCAL_USERS=$(rails runner "Actor.where(local: true).pluck(:username).each { |u| puts u }" 2>/dev/null)
    if [ -n "$LOCAL_USERS" ]; then
        echo "$LOCAL_USERS" | while read -r username; do
            if [ -n "$username" ]; then
                echo "  - $username"
            fi
        done
        
        # Test endpoints with first user
        FIRST_USER=$(echo "$LOCAL_USERS" | head -1)
        if [ -n "$FIRST_USER" ]; then
            echo ""
            print_info "エンドポイントテスト ($FIRST_USER を使用):"
            
            # Test Actor endpoint
            ACTOR_RESPONSE=$(curl -s -H "Accept: application/activity+json" http://localhost:3000/users/$FIRST_USER | jq -r '.id' 2>/dev/null)
            if [ "$ACTOR_RESPONSE" != "null" ] && [ -n "$ACTOR_RESPONSE" ]; then
                echo "  Actor ID: $ACTOR_RESPONSE"
            else
                echo "  Actor ID: エンドポイントアクセスエラー"
            fi
            
            # Test WebFinger
            WEBFINGER_RESPONSE=$(curl -s "http://localhost:3000/.well-known/webfinger?resource=acct:$FIRST_USER@$DOMAIN" | jq -r '.subject' 2>/dev/null)
            if [ "$WEBFINGER_RESPONSE" != "null" ] && [ -n "$WEBFINGER_RESPONSE" ]; then
                echo "  WebFinger: $WEBFINGER_RESPONSE"
            else
                echo "  WebFinger: エンドポイントアクセスエラー"
            fi
        fi
    else
        echo "  ローカルユーザーが見つかりません"
        echo "  次のコマンドでユーザーを作成してください: ./scripts/manage_accounts.sh"
    fi
    
    # Check database stats
    echo ""
    print_info "データベース統計:"
    rails runner "
      puts '  ローカルアクター数: ' + Actor.where(local: true).count.to_s
      puts '  リモートアクター数: ' + Actor.where(local: false).count.to_s
      puts '  投稿総数: ' + ActivityPubObject.count.to_s
      puts '  フォロー関係数: ' + Follow.count.to_s
      puts '  OAuthアプリケーション数: ' + Doorkeeper::Application.count.to_s
      puts '  アクセストークン数: ' + Doorkeeper::AccessToken.count.to_s
    " 2>/dev/null || echo "  データベースアクセスエラー"
    
else
    print_warning "サーバー状態: 停止中"
    echo "  次のコマンドでサーバーを起動してください: ./scripts/start_server.sh"
fi

# Show process information
echo ""
print_info "プロセス情報:"
RAILS_PROCS=$(ps aux | grep -c "[r]ails server" || echo "0")
QUEUE_PROCS=$(ps aux | grep -c "[s]olid.*queue" || echo "0")
echo "  Railsサーバープロセス数: $RAILS_PROCS"
echo "  Solid Queueプロセス数: $QUEUE_PROCS"

# Show recent domain history
echo ""
print_info "最近のドメイン履歴:"
if [ -f .env ]; then
    grep "^# -" .env | tail -5 | sed 's/^# - /  /' 2>/dev/null || echo "  履歴エントリが見つかりません"
else
    echo "  履歴は利用できません"
fi

# Show available management scripts
echo ""
print_info "利用可能な管理スクリプト:"
echo "  ./scripts/start_server.sh - サーバーの起動"
echo "  ./scripts/switch_domain.sh <ドメイン> - 新しいドメインに切り替え"
echo "  ./scripts/manage_accounts.sh - アカウント管理"
echo "  ./scripts/create_oauth_token.sh - OAuthトークンの生成"
echo "  ./scripts/create_test_posts.sh - テスト投稿の作成"
echo "  ./scripts/cleanup_and_start.sh - 強制クリーンアップと再起動"

echo ""
print_header "確認完了"