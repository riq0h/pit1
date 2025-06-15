#!/bin/bash

# フォローカウント修正スクリプト
# Usage: ./fix_follow_counts.sh

set -e

echo "=== Follow Count Fix Script ==="
echo ""

echo "Checking current follow counts..."

# 現在の状態を表示
rails runner "
puts '=== Current State ==='
Actor.where(local: true).each do |actor|
  following_count = Follow.where(actor: actor, accepted: true).count
  followers_count = Follow.where(target_actor: actor, accepted: true).count
  
  puts \"#{actor.username}:\"
  puts \"  DB following_count: #{actor.following_count} (actual: #{following_count})\"
  puts \"  DB followers_count: #{actor.followers_count} (actual: #{followers_count})\"
  puts \"  Needs fix: #{actor.following_count != following_count || actor.followers_count != followers_count}\"
  puts
end
"

echo ""
read -p "Fix follow counts? (y/N): " confirm

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Operation cancelled"
    exit 0
fi

echo ""
echo "Fixing follow counts..."

# カウント修正
rails runner "
fixed_count = 0
Actor.where(local: true).each do |actor|
  following_count = Follow.where(actor: actor, accepted: true).count
  followers_count = Follow.where(target_actor: actor, accepted: true).count
  
  if actor.following_count != following_count || actor.followers_count != followers_count
    puts \"Fixing #{actor.username}: following #{actor.following_count} -> #{following_count}, followers #{actor.followers_count} -> #{followers_count}\"
    actor.update!(following_count: following_count, followers_count: followers_count)
    fixed_count += 1
  else
    puts \"#{actor.username}: counts are correct\"
  end
end

puts \"\"
puts \"Fixed #{fixed_count} actors\"
"

echo ""
echo "✓ Follow count fix completed!"