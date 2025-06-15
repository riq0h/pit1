#!/bin/bash

# 改善されたサーバー起動スクリプト
# 環境変数の確認、プロセスクリーンアップ、設定修正を含む
set -e

echo "=== Letter Server Startup Script ==="
echo "Timestamp: $(date)"

# 1. 環境変数の読み込みと確認
echo "1. Loading and validating environment variables..."
if [ ! -f .env ]; then
    echo "ERROR: .env file not found"
    exit 1
fi

set -a
source .env
set +a

echo "   ACTIVITYPUB_DOMAIN: ${ACTIVITYPUB_DOMAIN:-NOT_SET}"
echo "   ACTIVITYPUB_PROTOCOL: ${ACTIVITYPUB_PROTOCOL:-NOT_SET}"

if [ -z "$ACTIVITYPUB_DOMAIN" ]; then
    echo "ERROR: ACTIVITYPUB_DOMAIN not set in .env"
    exit 1
fi

# 2. 既存プロセスのクリーンアップ
echo "2. Cleaning up existing processes..."
echo "   Stopping Rails servers..."
pkill -f "rails server" 2>/dev/null || true
pkill -f "puma.*pit1" 2>/dev/null || true

echo "   Stopping Solid Queue workers..."
pkill -f "solid_queue" 2>/dev/null || true
pkill -f "bin/jobs" 2>/dev/null || true

# プロセス終了を待つ
sleep 2

# 3. データベースの健全性チェック
echo "3. Checking database health..."
if ! rails runner 'Actor.count' >/dev/null 2>&1; then
    echo "   Database seems to have issues, running migrations..."
    rails db:migrate
fi

# 4. Actor URLの修正チェック
echo "4. Checking and fixing Actor URLs..."
rails runner "
actors_to_fix = Actor.where('ap_id LIKE ?', '%/actors/%')
if actors_to_fix.any?
  puts '   Found actors with incorrect URLs, fixing...'
  actors_to_fix.each do |actor|
    old_ap_id = actor.ap_id
    new_ap_id = old_ap_id.gsub('/actors/', '/users/')
    
    actor.update!(
      ap_id: new_ap_id,
      inbox_url: new_ap_id + '/inbox',
      outbox_url: new_ap_id + '/outbox',
      followers_url: new_ap_id + '/followers',
      following_url: new_ap_id + '/following'
    )
    puts \"   Fixed: #{old_ap_id} -> #{new_ap_id}\"
  end
else
  puts '   Actor URLs are correct'
end
"

# 5. 環境変数の正しい設定でサーバー起動
echo "5. Starting Rails server with correct environment..."

# バックグラウンドでサーバー起動
ACTIVITYPUB_DOMAIN="$ACTIVITYPUB_DOMAIN" \
ACTIVITYPUB_PROTOCOL="$ACTIVITYPUB_PROTOCOL" \
rails server -b 0.0.0.0 -p 3000 &

SERVER_PID=$!
echo "   Rails server started (PID: $SERVER_PID)"

# 6. Solid Queueの起動（1つだけ）
echo "6. Starting Solid Queue worker..."
ACTIVITYPUB_DOMAIN="$ACTIVITYPUB_DOMAIN" \
ACTIVITYPUB_PROTOCOL="$ACTIVITYPUB_PROTOCOL" \
bin/jobs &

JOBS_PID=$!
echo "   Solid Queue worker started (PID: $JOBS_PID)"

# 7. サーバーの起動確認
echo "7. Waiting for server to start..."
sleep 5

# ヘルスチェック
if curl -s "http://localhost:3000" >/dev/null; then
    echo "   ✓ Server is responding"
else
    echo "   ✗ Server is not responding"
fi

# 8. 設定の確認
echo "8. Verifying configuration..."
timeout 10 rails runner "
puts '   Domain configured as: ' + Rails.application.config.activitypub.base_url
puts '   Environment: ' + Rails.env
puts '   Database: ' + ActiveRecord::Base.connection.adapter_name
puts '   Actor count: ' + Actor.count.to_s
puts '   Local actors: ' + Actor.where(local: true).count.to_s
" 2>/dev/null || echo "   Configuration check timed out or failed"

echo ""
echo "=== Server Started Successfully ==="
echo "Rails Server: http://localhost:3000"
echo "Public URL: ${ACTIVITYPUB_PROTOCOL}://${ACTIVITYPUB_DOMAIN}"
echo "Server PID: $SERVER_PID"
echo "Jobs PID: $JOBS_PID"
echo ""
echo "To stop:"
echo "  kill $SERVER_PID $JOBS_PID"
echo "  or use: pkill -f 'rails server|solid_queue'"
echo ""
echo "Logs:"
echo "  tail -f log/development.log"