#!/bin/bash

# Letter ActivityPub Instance - Server Startup Script
# サーバー起動スクリプト

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

# Main function
main() {
    print_header "Letter ActivityPub サーバー起動"
    
    print_info "環境変数を読み込んでいます..."
    print_info "ドメイン: $ACTIVITYPUB_DOMAIN"
    print_info "プロトコル: $ACTIVITYPUB_PROTOCOL"
    echo ""
    
    print_info "既存のプロセスをクリーンアップしています..."
    pkill -f "rails server" 2>/dev/null || true
    pkill -f "solid.*queue" 2>/dev/null || true
    pkill -f "bin/jobs" 2>/dev/null || true
    
    sleep 2
    
    # PIDファイルクリーンアップ
    rm -f tmp/pids/server.pid
    print_success "プロセスクリーンアップが完了しました"
    
    print_info "Railsサーバーを起動しています..."
    ACTIVITYPUB_DOMAIN="$ACTIVITYPUB_DOMAIN" \
    ACTIVITYPUB_PROTOCOL="$ACTIVITYPUB_PROTOCOL" \
    rails server -b 0.0.0.0 -p 3000 -d
    
    if [[ $? -eq 0 ]]; then
        print_success "Railsサーバーが正常に起動しました"
    else
        print_error "Railsサーバーの起動に失敗しました"
        exit 1
    fi
    
    print_info "Solid Queueワーカーを起動しています..."
    ACTIVITYPUB_DOMAIN="$ACTIVITYPUB_DOMAIN" \
    ACTIVITYPUB_PROTOCOL="$ACTIVITYPUB_PROTOCOL" \
    nohup bin/jobs > log/solid_queue.log 2>&1 &
    
    if [[ $? -eq 0 ]]; then
        print_success "Solid Queueワーカーが正常に起動しました"
    else
        print_error "Solid Queueワーカーの起動に失敗しました"
        exit 1
    fi
    
    echo ""
    print_header "サーバー起動完了"
    print_info "接続情報:"
    echo "  ローカル: http://localhost:3000"
    echo "  公開URL: $ACTIVITYPUB_PROTOCOL://$ACTIVITYPUB_DOMAIN"
    echo ""
    print_info "ログ監視コマンド:"
    echo "  tail -f log/development.log log/solid_queue.log"
}

# Run main function
main "$@"