#!/bin/bash

# 改善されたサーバ起動スクリプト
# 環境変数の確認、プロセスクリーンアップ、設定修正を含む
set -e

echo "=== Letter サーバ起動スクリプト ==="
echo "実行時刻: $(date)"

# 1. 環境変数の読み込みと確認
echo "1. 環境変数の読み込みと検証中..."
if [ ! -f .env ]; then
    echo "エラー: .envファイルが見つかりません"
    exit 1
fi

set -a
source .env
set +a

echo "   ACTIVITYPUB_DOMAIN: ${ACTIVITYPUB_DOMAIN:-NOT_SET}"
echo "   ACTIVITYPUB_PROTOCOL: ${ACTIVITYPUB_PROTOCOL:-NOT_SET}"

if [ -z "$ACTIVITYPUB_DOMAIN" ]; then
    echo "エラー: .envファイルにACTIVITYPUB_DOMAINが設定されていません"
    exit 1
fi

# 2. 既存プロセスのクリーンアップ
echo "2. 既存プロセスのクリーンアップ中..."
echo "   Railsサーバを停止中..."
pkill -f "rails server" 2>/dev/null || true
pkill -f "puma.*pit1" 2>/dev/null || true

echo "   Solid Queueワーカーを停止中..."
pkill -f "solid_queue" 2>/dev/null || true
pkill -f "bin/jobs" 2>/dev/null || true

# プロセス終了を待つ
sleep 2

# 3. データベースの健全性チェック
echo "3. データベースの健全性をチェック中..."
if ! rails runner 'Actor.count' >/dev/null 2>&1; then
    echo "   データベースに問題があるようです。マイグレーションを実行中..."
    rails db:migrate
fi

# 4. Actor URLの修正チェック
echo "4. Actor URLの確認と修正中..."
rails runner "
actors_to_fix = Actor.where('ap_id LIKE ?', '%/actors/%')
if actors_to_fix.any?
  puts '   不正なURLのアクターが見つかりました。修正中...'
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
  puts '   Actor URLは正常です'
end
"

# 5. 環境変数の正しい設定でサーバ起動
echo "5. 正しい環境変数でRailsサーバを起動中..."

# バックグラウンドでサーバ起動
ACTIVITYPUB_DOMAIN="$ACTIVITYPUB_DOMAIN" \
ACTIVITYPUB_PROTOCOL="$ACTIVITYPUB_PROTOCOL" \
rails server -b 0.0.0.0 -p 3000 &

SERVER_PID=$!
echo "   Railsサーバが起動しました (PID: $SERVER_PID)"

# 6. Solid Queueの起動（1つだけ）
echo "6. Solid Queueワーカーを起動中..."
ACTIVITYPUB_DOMAIN="$ACTIVITYPUB_DOMAIN" \
ACTIVITYPUB_PROTOCOL="$ACTIVITYPUB_PROTOCOL" \
bin/jobs &

JOBS_PID=$!
echo "   Solid Queueワーカーが起動しました (PID: $JOBS_PID)"

# 7. サーバの起動確認
echo "7. サーバの起動を待機中..."
sleep 5

# ヘルスチェック
if curl -s "http://localhost:3000" >/dev/null; then
    echo "   ✓ サーバが応答しています"
else
    echo "   ✗ サーバが応答していません"
fi

# 8. Solid Queueワーカーの動作確認
echo "8. Solid Queueワーカーの動作確認中..."
sleep 2
QUEUE_RUNNING=$(ps aux | grep -c "[s]olid.*queue" || true)
if [ "$QUEUE_RUNNING" -gt 0 ]; then
    echo "   ✓ Solid Queueワーカーが動作中です"
    timeout 5 rails runner "
    pending_jobs = SolidQueue::Job.where(finished_at: nil).count
    puts '   待機中ジョブ数: ' + pending_jobs.to_s
    " 2>/dev/null || echo "   ジョブ状況確認がタイムアウトしました"
else
    echo "   ✗ Solid Queueワーカーが起動していません！"
    echo "   手動で再起動: bin/jobs &"
fi

# 9. 設定の確認
echo "9. 設定の確認中..."
timeout 10 rails runner "
puts '   Domain configured as: ' + Rails.application.config.activitypub.base_url
puts '   Environment: ' + Rails.env
puts '   Database: ' + ActiveRecord::Base.connection.adapter_name
puts '   Actor count: ' + Actor.count.to_s
puts '   Local actors: ' + Actor.where(local: true).count.to_s
" 2>/dev/null || echo "   設定確認がタイムアウトまたは失敗しました"

echo ""
echo "=== サーバが正常に起動しました ==="
echo "Railsサーバ: http://localhost:3000"
echo "パブリックURL: ${ACTIVITYPUB_PROTOCOL}://${ACTIVITYPUB_DOMAIN}"
echo "サーバPID: $SERVER_PID"
echo "ジョブPID: $JOBS_PID"
echo ""
echo "停止方法:"
echo "  kill $SERVER_PID $JOBS_PID"
echo "  または: pkill -f 'rails server|solid_queue'"
echo ""
echo "ログ確認:"
echo "  tail -f log/development.log"