#!/bin/bash

# インタラクティブユーザー作成スクリプト
# Usage: ./create_user_interactive.sh

set -e

echo "=== Letter User Creation Script ==="
echo ""

# 環境変数の読み込み
if [ ! -f .env ]; then
    echo "ERROR: .env file not found"
    exit 1
fi

set -a
source .env
set +a

echo "Domain: $ACTIVITYPUB_DOMAIN"
echo ""

# ユーザー名の入力
read -p "Enter username: " username

# パスワードの入力
read -p "Enter password: " password

# 表示名の入力（オプション）
read -p "Enter display name (optional, press Enter to use username): " display_name
if [[ -z "$display_name" ]]; then
    display_name="$username"
fi

echo ""
echo "Creating user..."

# ユーザー作成スクリプトの生成と実行
cat > tmp_create_user.rb << EOF
#!/usr/bin/env ruby

require 'openssl'

username = "$username"
password = "$password"
display_name = "$display_name"
domain = "$ACTIVITYPUB_DOMAIN"
protocol = "$ACTIVITYPUB_PROTOCOL"

begin
  # Generate keypair
  key = OpenSSL::PKey::RSA.new(2048)
  private_key = key.to_pem
  public_key = key.public_key.to_pem

  # Create actor with all required fields
  actor = Actor.create!(
    username: username,
    password: password,
    local: true,
    display_name: display_name,
    ap_id: "\#{protocol}://\#{domain}/users/\#{username}",
    inbox_url: "\#{protocol}://\#{domain}/users/\#{username}/inbox",
    outbox_url: "\#{protocol}://\#{domain}/users/\#{username}/outbox",
    followers_url: "\#{protocol}://\#{domain}/users/\#{username}/followers",
    following_url: "\#{protocol}://\#{domain}/users/\#{username}/following",
    public_key: public_key,
    private_key: private_key,
    actor_type: 'Person',
    discoverable: true,
    manually_approves_followers: false
  )

  puts "✓ User created successfully!"
  puts "  Username: \#{actor.username}"
  puts "  Display Name: \#{actor.display_name}"
  puts "  ActivityPub ID: \#{actor.ap_id}"

rescue => e
  puts "✗ Failed to create user: \#{e.message}"
  exit 1
end
EOF

# スクリプト実行
rails runner tmp_create_user.rb

# 一時ファイルの削除
rm -f tmp_create_user.rb