# 使用例とワークフロー

## 🚀 初回セットアップの完全ガイド

### 1. インスタンス初期化
```bash
cd /path/to/letter
./scripts/start_server.sh
```

### 2. 最初のユーザー作成
```bash
# アカウント管理スクリプト（2個制限を自動考慮）
./scripts/manage_accounts.sh
# 入力例:
# Username: admin
# Password: mypassword123
# Display name: Administrator
```

### 3. API アクセス用トークン生成
```bash
./scripts/create_oauth_token.sh
# 入力例:
# Username: admin
# 
# 出力されたトークンをメモ:
# Token: abcd1234567890...
```

### 4. テストデータ生成（オプション）
```bash
./scripts/create_test_posts.sh
# 入力例:
# Username: admin
# 
# 結果: 60件の多言語投稿が生成されます
```

### 5. フォローシステムのテスト
```bash
./scripts/test_follow.sh
# 入力例:
# Username: admin
# 
# 結果: FollowService、WebFingerServiceの動作確認
```

## 🔄 ドメイン変更ワークフロー

### トンネルURLの期限切れ時
```bash
# 1. 現在の状態確認
./scripts/check_domain.sh

# 2. 新しいドメインに変更
./scripts/switch_domain.sh abc123.serveo.net https

# 3. 動作確認
./scripts/check_domain.sh
```

## 🐛 トラブルシューティング例

### ケース1: サーバーが応答しない
```bash
# 症状: curl でアクセスできない
# 解決方法:
./scripts/cleanup_and_start.sh
```

### ケース2: 環境変数が反映されない
```bash
# 症状: ドメインがlocalhost:3000のまま
# 解決方法:
source scripts/load_env.sh
run_with_env "puts Rails.application.config.activitypub.base_url"

# または
./scripts/cleanup_and_start.sh
```

### ケース3: Solid Queueプロセスが大量にある
```bash
# 症状: ps aux でsolid_queueが何十個も表示
# 解決方法:
./scripts/cleanup_and_start.sh
```

### ケース4: アカウントが破損して削除できない
```bash
# 症状: manage_accounts.sh でアカウント削除に失敗
# 解決方法:
./scripts/delete_account.sh username_or_id

# 使用例:
./scripts/delete_account.sh broken_user
./scripts/delete_account.sh 5
```

## 📊 日常運用のベストプラクティス

### 毎日の健康チェック
```bash
./scripts/check_domain.sh
```

## 🔧 開発者向けワークフロー

### 新機能テスト用ユーザー作成
```bash
./scripts/manage_accounts.sh
# 既存のアカウント状況に応じた作成・削除

./scripts/create_oauth_token.sh
# Username: testuser001

# テスト完了後のクリーンアップ
./scripts/delete_account.sh testuser001
```

### API動作テスト
```bash
# トークン取得後
export TOKEN="your_token_here"
export DOMAIN="your_domain_here"

# アカウント情報取得
curl -H "Authorization: Bearer $TOKEN" \
     "https://$DOMAIN/api/v1/accounts/verify_credentials"

# 投稿作成
curl -X POST \
     -H "Authorization: Bearer $TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"status":"Hello from API!","visibility":"public"}' \
     "https://$DOMAIN/api/v1/statuses"

# アバター設定（Mastodon API準拠）
curl -X PATCH \
     -H "Authorization: Bearer $TOKEN" \
     -F "avatar=@/path/to/image.png" \
     "https://$DOMAIN/api/v1/accounts/update_credentials"
```

## 📈 モニタリングコマンド

### リアルタイムログ監視
```bash
tail -f log/development.log log/solid_queue.log
```

### プロセス監視
```bash
watch -n 5 'ps aux | grep -E "rails|solid" | grep -v grep'
```

### データベース統計
```bash
source scripts/load_env.sh && run_with_env "
puts 'Users: ' + Actor.where(local: true).count.to_s
puts 'Posts: ' + ActivityPubObject.count.to_s
puts 'Follows: ' + Follow.count.to_s
puts 'Base URL: ' + Rails.application.config.activitypub.base_url
"
```

## 🌐 外部連携テスト

### WebFinger確認
```bash
curl "https://your-domain/.well-known/webfinger?resource=acct:username@your-domain"
```

### ActivityPub プロファイル確認
```bash
curl -H "Accept: application/activity+json" \
     "https://your-domain/users/username"
```

### 他インスタンスからのフォロー
```bash
# 他のMastodonインスタンスから
# @username@your-domain を検索してフォロー
```

## ❗ 注意事項

1. **本番環境での使用前に必ずテスト環境で動作確認してください**
2. **ドメイン変更は外部インスタンスとの連携に影響します**
3. **定期的にログを確認し、エラーがないかチェックしてください**
4. **OAuthトークンは安全に管理してください**