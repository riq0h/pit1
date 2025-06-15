#!/bin/bash

# 改良版サーバー起動スクリプト
# .envファイルから環境変数を読み込んでRailsサーバーとSolid Queueを起動
# Usage: ./start_server.sh

set -e

echo "=== Letter Server Startup ==="

# 環境変数の読み込み
source scripts/load_env.sh

# 既存のプロセスをクリーンアップ
echo "Cleaning up existing processes..."
pkill -f "rails server" 2>/dev/null || true
pkill -f "solid.*queue" 2>/dev/null || true
pkill -f "bin/jobs" 2>/dev/null || true

sleep 2

# PIDファイルクリーンアップ
rm -f tmp/pids/server.pid

# 正しい環境変数でサーバーを起動
echo "Starting Rails server..."
ACTIVITYPUB_DOMAIN="$ACTIVITYPUB_DOMAIN" \
ACTIVITYPUB_PROTOCOL="$ACTIVITYPUB_PROTOCOL" \
rails server -b 0.0.0.0 -p 3000 -d

# Solid Queueワーカーを起動（1つだけ）
echo "Starting Solid Queue worker..."
ACTIVITYPUB_DOMAIN="$ACTIVITYPUB_DOMAIN" \
ACTIVITYPUB_PROTOCOL="$ACTIVITYPUB_PROTOCOL" \
nohup bin/jobs > log/solid_queue.log 2>&1 &

echo ""
echo "✓ Rails server and Solid Queue worker started"
echo "  Local: http://localhost:3000"
echo "  Public: $ACTIVITYPUB_PROTOCOL://$ACTIVITYPUB_DOMAIN"
echo ""
echo "Logs: tail -f log/development.log log/solid_queue.log"