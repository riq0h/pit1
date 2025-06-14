#!/bin/bash

# .envファイルから環境変数を読み込んでRailsサーバーとSolid Queueを起動
# Usage: ./start_server.sh

set -a  # 環境変数を自動的にexport
source .env
set +a

# 既存のプロセスをクリーンアップ
pkill -f "rails server" 2>/dev/null || true
pkill -f "solid_queue" 2>/dev/null || true

# サーバーを起動
rails server -p 3000 -d

# Solid Queueワーカーを起動（バックグラウンド）
bin/jobs &

echo "Rails server and Solid Queue workers started"
echo "Rails server: http://localhost:3000"
echo "Domain: $ACTIVITYPUB_DOMAIN"