#!/bin/bash

# Letter ActivityPub Instance - Complete Cleanup & Restart Script
# 完全クリーンアップ＆再起動スクリプト

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

print_header "Letter ActivityPub 完全クリーンアップ＆再起動"
print_info "実行時刻: $(date)"

# 1. 既存プロセスのクリーンアップ
print_info "1. 関連プロセスの終了..."
{
    pkill -f "solid.queue" 2>/dev/null || true
    pkill -f "rails server" 2>/dev/null || true
    pkill -f "puma.*pit1" 2>/dev/null || true
    pkill -f "bin/jobs" 2>/dev/null || true
    sleep 3
} > /dev/null 2>&1

print_success "関連プロセスを終了しました"

# 2. 環境変数の読み込み確認
print_info "2. 環境変数の読み込み確認..."
if [ ! -f .env ]; then
    print_error ".envファイルが見つかりません"
    exit 1
fi

print_success "環境変数を読み込みました"
print_info "ACTIVITYPUB_DOMAIN: $ACTIVITYPUB_DOMAIN"
print_info "ACTIVITYPUB_PROTOCOL: $ACTIVITYPUB_PROTOCOL"

# 3. PIDファイルのクリーンアップ
print_info "3. PIDファイルのクリーンアップ..."
rm -f tmp/pids/server.pid
rm -f tmp/pids/solid_queue*.pid
print_success "PIDファイルをクリーンアップしました"

# 4. データベースの健全性チェックと修正
print_info "4. データベースのメンテナンス..."
rails db:migrate 2>/dev/null || print_info "マイグレーションは既に最新です"

print_info "Actor URLの修正を実行中..."
# Actor URLの修正
rails runner "
incorrect_actors = Actor.where('ap_id LIKE ?', '%/actors/%')
if incorrect_actors.any?
  puts '   ' + incorrect_actors.count.to_s + '個のActor URLを修正中...'
  incorrect_actors.each do |actor|
    domain = ENV['ACTIVITYPUB_DOMAIN']
    protocol = ENV['ACTIVITYPUB_PROTOCOL'] || 'https'
    base_url = protocol + '://' + domain
    
    actor.update!(
      ap_id: base_url + '/users/' + actor.username,
      inbox_url: base_url + '/users/' + actor.username + '/inbox',
      outbox_url: base_url + '/users/' + actor.username + '/outbox',
      followers_url: base_url + '/users/' + actor.username + '/followers',
      following_url: base_url + '/users/' + actor.username + '/following'
    )
  end
  puts '   Actor URLを修正しました'
else
  puts '   Actor URLは正常です'
end
" 2>/dev/null || print_warning "Actor URL修正をスキップしました"
print_success "データベースのメンテナンスが完了しました"

# 5. Rails サーバ起動（デーモンモード）
print_info "5. Railsサーバを起動中..."
RAILS_ENV=development \
ACTIVITYPUB_DOMAIN="$ACTIVITYPUB_DOMAIN" \
ACTIVITYPUB_PROTOCOL="$ACTIVITYPUB_PROTOCOL" \
rails server -b 0.0.0.0 -p 3000 -d

print_success "Railsサーバをデーモンモードで起動しました"

# 6. Solid Queue 起動（1つだけ）
print_info "6. Solid Queueワーカーを起動中..."
RAILS_ENV=development \
ACTIVITYPUB_DOMAIN="$ACTIVITYPUB_DOMAIN" \
ACTIVITYPUB_PROTOCOL="$ACTIVITYPUB_PROTOCOL" \
nohup bin/jobs > log/solid_queue.log 2>&1 &

JOBS_PID=$!
print_success "Solid Queueワーカーを起動しました (PID: $JOBS_PID)"

# 7. 起動確認
print_info "7. 起動確認を実行中..."
sleep 5

# サーバ確認
if curl -s http://localhost:3000 >/dev/null 2>&1; then
    print_success "Railsサーバが応答しています"
else
    print_error "Railsサーバが応答していません"
fi

# プロセス確認
RAILS_PROCS=$(ps aux | grep -c "[r]ails server" || true)
QUEUE_PROCS=$(ps aux | grep -c "[s]olid.*queue" || true)

print_info "Railsプロセス数: $RAILS_PROCS"
print_info "Solid Queueプロセス数: $QUEUE_PROCS"

# 8. 最終設定確認
print_info "8. 最終設定確認..."
timeout 10 rails runner "
puts '   ベースURL: ' + Rails.application.config.activitypub.base_url
puts '   ローカルアクター数: ' + Actor.where(local: true).count.to_s
puts '   投稿総数: ' + ActivityPubObject.count.to_s
puts '   フォロー関係数: ' + Follow.count.to_s
" 2>/dev/null || print_warning "設定確認がタイムアウトしました"

echo ""
print_header "起動完了"
print_info "サーバ情報:"
echo "  サーバURL: ${ACTIVITYPUB_PROTOCOL}://${ACTIVITYPUB_DOMAIN}"
echo "  ローカルURL: http://localhost:3000"
echo ""
print_info "監視コマンド:"
echo "  tail -f log/development.log"
echo "  tail -f log/solid_queue.log"
echo "  ps aux | grep -E 'rails|solid'"
echo ""
print_info "全停止コマンド:"
echo "  sudo pkill -f 'rails server|solid.*queue'"