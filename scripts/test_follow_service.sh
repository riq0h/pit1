#!/bin/bash

# FollowServiceのテストスクリプト
# Usage: ./test_follow_service.sh

set -e

echo "=== Follow Service Test Script ==="
echo ""

# ユーザー名の入力
read -p "Enter username to test with: " username

# テスト対象の入力
read -p "Enter account to follow (@username@domain): " target_account

echo ""
echo "Testing FollowService..."

# FollowServiceのテスト
cat > tmp_test_follow_service.rb << EOF
#!/usr/bin/env ruby

username = "$username"
target_account = "$target_account"

begin
  # Find the actor
  actor = Actor.find_by(username: username, local: true)
  unless actor
    puts "✗ Actor '\#{username}' not found"
    exit 1
  end

  puts "✓ Found actor: \#{actor.username}"
  
  # Initialize FollowService
  follow_service = FollowService.new(actor)
  
  puts "✓ FollowService initialized"
  
  # Attempt to follow
  puts "Attempting to follow: \#{target_account}"
  
  follow = follow_service.follow!(target_account)
  
  if follow
    puts "✓ Follow successful!"
    puts "  Follow ID: \#{follow.id}"
    puts "  Target: \#{follow.target_actor.username}@\#{follow.target_actor.domain || 'local'}"
    puts "  Accepted: \#{follow.accepted}"
    puts "  AP ID: \#{follow.ap_id}"
    
    # Check counts
    actor.reload
    puts ""
    puts "Updated counts:"
    puts "  Following: \#{actor.following_count}"
    puts "  Followers: \#{actor.followers_count}"
  else
    puts "✗ Follow failed"
  end

rescue => e
  puts "✗ Error: \#{e.message}"
  puts e.backtrace.first(5).join("\n")
  exit 1
end
EOF

# スクリプト実行
rails runner tmp_test_follow_service.rb

# 一時ファイルの削除
rm -f tmp_test_follow_service.rb

echo ""
echo "✓ Follow service test completed!"