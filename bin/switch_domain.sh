#!/bin/bash

# Letter ActivityPub Instance - Domain Switch Script
# ドメイン切り替えスクリプト
# 使用法: ./switch_domain.sh <新しいドメイン> [プロトコル]
# 例: ./switch_domain.sh abc123.serveo.net https

set -e

# Get the directory of this script and the project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Change to project root to ensure relative paths work
cd "$PROJECT_ROOT"

# Load environment variables
source bin/load_env.sh

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

# Main function
main() {
    print_header "Letter ActivityPub ドメイン切り替え"
    
    # Check arguments
    if [ $# -lt 1 ]; then
        print_error "使用法: $0 <新しいドメイン> [プロトコル]"
        print_error "例: $0 abc123.serveo.net https"
        exit 1
    fi
    
    NEW_DOMAIN="$1"
    NEW_PROTOCOL="${2:-https}"
    
    print_info "ドメイン切り替え処理を開始します..."
    print_info "新しいドメイン: $NEW_DOMAIN"
    print_info "プロトコル: $NEW_PROTOCOL"
    
    # Get current domain from .env
    CURRENT_DOMAIN=$(grep "^ACTIVITYPUB_DOMAIN=" .env | cut -d'=' -f2)
    print_info "現在のドメイン: $CURRENT_DOMAIN"
    
    # Confirm the change
    echo ""
    print_warning "この操作により以下が実行されます:"
    echo "  1. .envファイルの更新"
    echo "  2. 現在のサーバの停止"
    echo "  3. データベース内のActor URLの更新"
    echo "  4. 新しいドメインでのサーバ再起動"
    echo ""
    read -p "続行しますか? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "操作をキャンセルしました"
        exit 0
    fi
    
    print_info "ステップ 1/5: .envファイルの更新..."
    
    # Update .env file
    sed -i "s/^ACTIVITYPUB_DOMAIN=.*/ACTIVITYPUB_DOMAIN=$NEW_DOMAIN/" .env
    sed -i "s/^ACTIVITYPUB_PROTOCOL=.*/ACTIVITYPUB_PROTOCOL=$NEW_PROTOCOL/" .env
    
    print_success ".envファイルを更新しました"
    
    print_info "ステップ 2/5: 現在のサーバを停止中..."
    
    # Stop current server
    pkill -f "rails server" 2>/dev/null || true
    pkill -f "puma" 2>/dev/null || true
    rm -f tmp/pids/server.pid
    
    print_success "サーバを停止しました"
    
    print_info "ステップ 3/5: データベース内のActor URLを更新中..."

    # Create Ruby script for database update
    cat > /tmp/update_actor_for_domain_switch.rb << 'EOF'
# Update all local Actor URLs to new domain
local_actors = Actor.where(local: true)

if local_actors.any?
  new_base_url = Rails.application.config.activitypub.base_url
  puts "#{local_actors.count}個のローカルアクターのドメインを更新します: #{new_base_url}"
  
  local_actors.each do |actor|
    old_ap_id = actor.ap_id
    old_icon_url = actor.icon_url
    old_header_url = actor.header_url
    
    # Build update hash
    update_params = {
      ap_id: "#{new_base_url}/users/#{actor.username}",
      inbox_url: "#{new_base_url}/users/#{actor.username}/inbox",
      outbox_url: "#{new_base_url}/users/#{actor.username}/outbox",
      followers_url: "#{new_base_url}/users/#{actor.username}/followers",
      following_url: "#{new_base_url}/users/#{actor.username}/following"
    }
    
    # Update icon_url if it exists and contains old domain
    if old_icon_url.present? && old_icon_url.include?('/system/accounts/')
      # Extract the filename part after /system/accounts/
      icon_path = old_icon_url.split('/system/accounts/').last
      update_params[:icon_url] = "#{new_base_url}/system/accounts/#{icon_path}"
    end
    
    # Update header_url if it exists and contains old domain
    if old_header_url.present? && old_header_url.include?('/system/accounts/')
      # Extract the filename part after /system/accounts/
      header_path = old_header_url.split('/system/accounts/').last
      update_params[:header_url] = "#{new_base_url}/system/accounts/#{header_path}"
    end
    
    actor.update!(update_params)
    
    puts "  ✓ #{actor.username}を更新しました:"
    puts "    AP ID: #{old_ap_id} -> #{actor.ap_id}"
    if old_icon_url != actor.icon_url
      puts "    アイコン: #{old_icon_url} -> #{actor.icon_url}"
    end
    if old_header_url != actor.header_url
      puts "    ヘッダー: #{old_header_url} -> #{actor.header_url}"
    end
  end
  
  puts "すべてのローカルアクターの更新が完了しました!"
else
  puts "ローカルアクターが見つかりません"
end
EOF
    
    # Load environment variables and run database update
    set -a
    source .env
    set +a
    RAILS_ENV=development rails runner /tmp/update_actor_for_domain_switch.rb
    
    # Clean up temporary file
    rm -f /tmp/update_actor_for_domain_switch.rb
    
    print_success "データベースのURLを更新しました"
    
    print_info "ステップ 4/5: サーバを再起動中..."
    
    # Start server with new configuration
    "$SCRIPT_DIR/start_server.sh"
    
    print_success "新しいドメインでサーバを再起動しました"
    
    print_info "ステップ 5/5: 設定を確認中..."
    
    # Wait a moment for server to start
    sleep 3
    
    # Verify the new configuration
    echo ""
    print_header "ドメイン切り替え完了"
    print_info "確認情報:"
    echo "  サーバ: http://localhost:3000"
    echo "  ドメイン: $NEW_DOMAIN"
    echo "  プロトコル: $NEW_PROTOCOL"
    
    # Check which users exist and show examples
    FIRST_USER=$(rails runner "puts Actor.where(local: true).first&.username" 2>/dev/null)
    if [ -n "$FIRST_USER" ]; then
      echo "  サンプルActor URL: $NEW_PROTOCOL://$NEW_DOMAIN/users/$FIRST_USER"
      echo "  サンプルWebFinger: http://localhost:3000/.well-known/webfinger?resource=acct:$FIRST_USER@$NEW_DOMAIN"
      
      print_success "ドメイン切り替えが正常に完了しました!"
      print_warning "外部インスタンスが新しいドメインを認識するまで数分かかる場合があります"
      
      echo ""
      print_info "テストコマンド:"
      echo "  curl -H \"Accept: application/activity+json\" http://localhost:3000/users/$FIRST_USER | jq '.id'"
      echo "  curl \"http://localhost:3000/.well-known/webfinger?resource=acct:$FIRST_USER@$NEW_DOMAIN\" | jq '.subject'"
    else
      print_success "ドメイン切り替えが正常に完了しました!"
      print_warning "ローカルユーザが見つかりません。次のコマンドでユーザを作成してください: ./scripts/manage_accounts.sh"
    fi
}

# Run main function
main "$@"