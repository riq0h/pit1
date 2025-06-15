#!/bin/bash

# 完全クリーンアップ＆再起動スクリプト
set -e

echo "=== Letter Server Complete Cleanup & Restart ==="
echo "Timestamp: $(date)"

# 1. 強制的なプロセスクリーンアップ
echo "1. Force cleaning all related processes..."
sudo pkill -9 -f "solid.queue" 2>/dev/null || true
sudo pkill -9 -f "rails server" 2>/dev/null || true
sudo pkill -9 -f "puma.*pit1" 2>/dev/null || true
sudo pkill -9 -f "bin/jobs" 2>/dev/null || true

# 少し待つ
sleep 3

# 2. 環境変数の読み込み
echo "2. Loading environment variables..."
if [ ! -f .env ]; then
    echo "ERROR: .env file not found"
    exit 1
fi

set -a
source .env
set +a

echo "   ACTIVITYPUB_DOMAIN: $ACTIVITYPUB_DOMAIN"
echo "   ACTIVITYPUB_PROTOCOL: $ACTIVITYPUB_PROTOCOL"

# 3. PIDファイルのクリーンアップ
echo "3. Cleaning PID files..."
rm -f tmp/pids/server.pid
rm -f tmp/pids/solid_queue*.pid

# 4. データベースの健全性チェックと修正
echo "4. Database maintenance..."
rails db:migrate 2>/dev/null || echo "   Migrations already up to date"

# Actor URLの修正
rails runner "
begin
  incorrect_actors = Actor.where('ap_id LIKE ?', '%/actors/%')
  if incorrect_actors.any?
    puts '   Fixing #{incorrect_actors.count} actor URLs...'
    incorrect_actors.each do |actor|
      domain = ENV['ACTIVITYPUB_DOMAIN']
      protocol = ENV['ACTIVITYPUB_PROTOCOL'] || 'https'
      base_url = \"#{protocol}://#{domain}\"
      
      actor.update!(
        ap_id: \"#{base_url}/users/#{actor.username}\",
        inbox_url: \"#{base_url}/users/#{actor.username}/inbox\",
        outbox_url: \"#{base_url}/users/#{actor.username}/outbox\",
        followers_url: \"#{base_url}/users/#{actor.username}/followers\",
        following_url: \"#{base_url}/users/#{actor.username}/following\"
      )
    end
    puts '   Actor URLs fixed'
  else
    puts '   Actor URLs are correct'
  end
rescue => e
  puts \"   Error fixing actors: #{e.message}\"
end
"

# 5. Rails サーバー起動（デーモンモード）
echo "5. Starting Rails server..."
RAILS_ENV=development \
ACTIVITYPUB_DOMAIN="$ACTIVITYPUB_DOMAIN" \
ACTIVITYPUB_PROTOCOL="$ACTIVITYPUB_PROTOCOL" \
rails server -b 0.0.0.0 -p 3000 -d

echo "   Rails server started in daemon mode"

# 6. Solid Queue 起動（1つだけ）
echo "6. Starting single Solid Queue worker..."
RAILS_ENV=development \
ACTIVITYPUB_DOMAIN="$ACTIVITYPUB_DOMAIN" \
ACTIVITYPUB_PROTOCOL="$ACTIVITYPUB_PROTOCOL" \
nohup bin/jobs > log/solid_queue.log 2>&1 &

JOBS_PID=$!
echo "   Solid Queue started (PID: $JOBS_PID)"

# 7. 起動確認
echo "7. Verifying startup..."
sleep 5

# サーバー確認
if curl -s http://localhost:3000 >/dev/null 2>&1; then
    echo "   ✓ Rails server is responding"
else
    echo "   ✗ Rails server is not responding"
fi

# プロセス確認
RAILS_PROCS=$(ps aux | grep -c "[r]ails server" || true)
QUEUE_PROCS=$(ps aux | grep -c "[s]olid.*queue" || true)

echo "   Rails processes: $RAILS_PROCS"
echo "   Solid Queue processes: $QUEUE_PROCS"

# 8. 最終設定確認
echo "8. Final configuration check..."
timeout 10 rails runner "
begin
  puts '   Base URL: ' + Rails.application.config.activitypub.base_url
  puts '   Local actors: ' + Actor.where(local: true).count.to_s
  puts '   Total posts: ' + ActivityPubObject.count.to_s
  puts '   Follows: ' + Follow.count.to_s
rescue => e
  puts '   Config check failed: ' + e.message
end
" 2>/dev/null || echo "   Configuration check timed out"

echo ""
echo "=== Startup Complete ==="
echo "Server URL: ${ACTIVITYPUB_PROTOCOL}://${ACTIVITYPUB_DOMAIN}"
echo "Local URL: http://localhost:3000"
echo ""
echo "Monitoring commands:"
echo "  tail -f log/development.log"
echo "  tail -f log/solid_queue.log"
echo "  ps aux | grep -E 'rails|solid'"
echo ""
echo "To stop all:"
echo "  sudo pkill -f 'rails server|solid.*queue'"