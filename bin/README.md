# Letter ActivityPub Instance Management Scripts

bin/ディレクトリには、ActivityPub機能を管理するためのスクリプトが含まれています。

## 📋 スクリプト一覧

### 🚀 サーバ管理

#### `cleanup_and_start.sh`
**用途**: 再起動および起動
**使用法**: `./cleanup_and_start.sh`  
**説明**: 全プロセスを強制終了し、設定を修正してから再起動します。

#### `load_env.sh`
**用途**: 環境変数読み込みヘルパー  
**使用法**: `source bin/load_env.sh`  
**説明**: .envファイルから環境変数を確実に読み込み、Rails runnerのラッパー関数を提供します。

### 🔧 設定管理

#### `switch_domain.sh`
**用途**: ドメイン変更  
**使用法**: `./switch_domain.sh <新しいドメイン> [プロトコル]`  
**例**: `./switch_domain.sh abc123.serveo.net https`  
**説明**: ActivityPubドメインを変更し、全ユーザのURLを更新します。

#### `check_domain.sh`
**用途**: 現在の設定確認  
**使用法**: `./check_domain.sh`  
**説明**: ドメイン設定、サーバ状態、データベース統計、エンドポイントの動作を確認します。

### 👤 ユーザ管理

#### `manage_accounts.sh`
**用途**: アカウント管理  
**使用法**: `./manage_accounts.sh`  
**説明**: 2個制限を考慮したアカウント作成・削除を管理。既存アカウントの状況に応じて適切な操作を案内します。

#### `create_oauth_token.sh`
**用途**: OAuth トークン生成  
**使用法**: `./create_oauth_token.sh`  
**説明**: 指定したユーザ用のOAuthアクセストークンを生成します。API使用に必要。

#### `generate_vapid.sh`
**用途**: VAPID キー生成  
**使用法**: `./generate_vapid.sh`  
**説明**: Web Push通知用のVAPID (Voluntary Application Server Identification) キーペアを生成します。
**注意**: VAPIDキー変更により既存のプッシュ通知サブスクリプションが無効化されます。

#### `delete_account.sh`
**用途**: アカウント削除  
**使用法**: `./delete_account.sh <ユーザ名またはID>`  
**例**: `./delete_account.sh tester` または `./delete_account.sh 4`  
**説明**: 指定したアカウントとすべての関連データを完全に削除します。OAuth tokens、投稿、フォロー関係、メディアなど、すべての依存レコードを適切な順序で削除し、データベースの整合性を保ちます。

## 🔧 環境変数の確実な読み込み

### load_env.sh の使用方法

環境変数読み込み問題を解決するため、`load_env.sh`ヘルパーを使用してください：

```bash
# 環境変数を読み込んでからRails runnerを実行
source bin/load_env.sh
run_with_env "puts Rails.application.config.activitypub.base_url"

# または一行で
source bin/load_env.sh && run_with_env "your_ruby_code"
```
