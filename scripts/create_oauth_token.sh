#!/bin/bash

# OAuthトークン生成スクリプト
# Usage: ./create_oauth_token.sh

set -e

echo "=== OAuth Token Generation Script ==="
echo ""

# ユーザー名の入力
read -p "Enter username: " username

echo ""
echo "Generating OAuth token for user: $username"

# トークン生成スクリプトの実行
cat > tmp_create_token.rb << EOF
#!/usr/bin/env ruby

username = "$username"

begin
  # Find user
  actor = Actor.find_by(username: username, local: true)
  unless actor
    puts "✗ User '\#{username}' not found"
    exit 1
  end

  # Create or find OAuth application
  app = Doorkeeper::Application.find_or_create_by(uid: "test_client_\#{username}") do |a|
    a.name = "Test Client for \#{username}"
    a.secret = SecureRandom.hex(32)
    a.redirect_uri = "urn:ietf:wg:oauth:2.0:oob"
    a.scopes = "read write follow"
  end

  # Create access token
  token = Doorkeeper::AccessToken.create!(
    application: app,
    resource_owner_id: actor.id,
    scopes: "read write follow"
  )

  puts "✓ OAuth token created successfully!"
  puts ""
  puts "Application Details:"
  puts "  Name: \#{app.name}"
  puts "  Client ID: \#{app.uid}"
  puts "  Client Secret: \#{app.secret}"
  puts ""
  puts "Access Token:"
  puts "  Token: \#{token.token}"
  puts "  Scopes: \#{token.scopes}"
  puts "  User: \#{actor.username}"
  puts ""
  puts "API Usage Example:"
  puts "  curl -H \"Authorization: Bearer \#{token.token}\" \\"
  puts "       \"https://\#{ENV['ACTIVITYPUB_DOMAIN']}/api/v1/accounts/verify_credentials\""

rescue => e
  puts "✗ Failed to create token: \#{e.message}"
  exit 1
end
EOF

# スクリプト実行
rails runner tmp_create_token.rb

# 一時ファイルの削除
rm -f tmp_create_token.rb