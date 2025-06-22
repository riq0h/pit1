# Mastodonクライアント互換性対応ガイド

## 概要

LetterでサードパーティMastodonクライアント（Elk、Phanpy、Pinafore等）を使用可能にするための実装内容をまとめます。

## 主要な問題と解決策

### 1. OAuth アプリケーション登録の500エラー

**問題**: 
Mastodonクライアントが `POST /api/v1/apps` でアプリケーション登録を試行すると500エラーが発生。

**原因**: 
Doorkeeper::Applicationモデルに `website` カラムが存在しないため、以下のエラーが発生：
```
ActiveModel::UnknownAttributeError (unknown attribute 'website' for Doorkeeper::Application.)
```

**解決策**:
1. マイグレーションでwebsiteカラムを追加：
```ruby
# db/migrate/xxxx_create_doorkeeper_tables.rb
create_table :oauth_applications do |t|
  t.string  :name,         null: false
  t.string  :uid,          null: false
  t.string  :secret,       null: false
  t.text    :redirect_uri, null: false
  t.string  :scopes,       null: false, default: ''
  t.boolean :confidential, null: false, default: true
  t.text    :website       # この行を追加
  t.timestamps             null: false
end
```

2. Apps controllerでwebsiteパラメータを処理：
```ruby
# app/controllers/api/v1/apps_controller.rb
def application_params
  client_name = params[:client_name]
  redirect_uris = params[:redirect_uris]
  
  if client_name.blank? || redirect_uris.blank?
    raise ActionController::ParameterMissing, 'client_name and redirect_uris are required'
  end

  {
    name: client_name,
    redirect_uri: redirect_uris,
    scopes: params[:scopes] || 'read',
    website: params[:website],  # websiteパラメータを含める
    confidential: false
  }
end

def serialized_application(application)
  {
    id: application.id.to_s,
    name: application.name,
    website: application.website,  # websiteフィールドを返す
    redirect_uri: application.redirect_uri,
    client_id: application.uid,
    client_secret: application.secret,
    vapid_key: ENV['VAPID_PUBLIC_KEY'] || 'not_configured'
  }
end
```

### 2. CORS設定

**必要な設定**:
```ruby
# config/initializers/cors.rb
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins '*'
    
    resource '/api/*',
             headers: :any,
             methods: [:get, :post, :put, :patch, :delete, :options, :head],
             expose: ['Link', 'X-RateLimit-Reset', 'X-RateLimit-Limit', 'X-RateLimit-Remaining', 'X-Request-Id']
  end

  allow do
    origins '*'
    
    resource '/oauth/*',
             headers: :any,
             methods: [:get, :post, :put, :patch, :delete, :options, :head]
  end

  allow do
    origins '*'
    
    resource '/.well-known/*',
             headers: :any,
             methods: [:get, :options, :head]
  end
end
```

### 3. クライアント固有の問題と対応

#### 3.1 Pinafore
- **動作**: 正常に自動アプリケーション登録を行う
- **特記事項**: websiteカラム追加後は完全に機能

#### 3.2 Elk
- **問題**: 自動アプリケーション登録を行わず、固定のclient_idを使用
- **固定credentials**:
  - client_id: `kRRwQCSWutPh2bgLnUK_H8Grh6o7_gtK-oqtUk2tycM`
  - client_secret: `OiCDvJPLFQpIYW64vW9Q4-xzCV0E3PTNNd2SRHplL68`
  - redirect_uri: `https://elk.zone/api/[DOMAIN]/oauth/https%3A%2F%2Felk.zone`

#### 3.3 Phanpy
- **問題**: 自動アプリケーション登録を行わず、固定のclient_idを使用
- **固定credentials**:
  - client_id: `Ymh-1lDmq3eIojOhOpMZCekpm9wJ4sqK8Ae3ax1MK48`
  - client_secret: `qwdvDzJ3ijdUaygV7cvKocC9K0eKH1UTBMx_gTkE5n4`
  - redirect_uri: `https://phanpy.social`

### 4. 固定クライアントアプリケーションの事前作成

ElkとPhanpyは自動登録を行わないため、以下のスクリプトで事前にアプリケーションを作成：

```ruby
# 固定クライアント用アプリケーション作成スクリプト
clients = [
  {
    name: 'elk',
    uid: 'kRRwQCSWutPh2bgLnUK_H8Grh6o7_gtK-oqtUk2tycM',
    secret: 'OiCDvJPLFQpIYW64vW9Q4-xzCV0E3PTNNd2SRHplL68',
    redirect_uri: 'https://elk.zone/api/[YOUR_DOMAIN]/oauth/https%3A%2F%2Felk.zone'
  },
  {
    name: 'Phanpy',
    uid: 'Ymh-1lDmq3eIojOhOpMZCekpm9wJ4sqK8Ae3ax1MK48',
    secret: 'qwdvDzJ3ijdUaygV7cvKocC9K0eKH1UTBMx_gTkE5n4',
    redirect_uri: 'https://phanpy.social'
  }
]

clients.each do |client|
  existing = Doorkeeper::Application.find_by(uid: client[:uid])
  unless existing
    Doorkeeper::Application.create!(
      name: client[:name],
      uid: client[:uid],
      secret: client[:secret],
      redirect_uri: client[:redirect_uri],
      scopes: 'read write follow push',
      confidential: true
    )
    puts "Created application: #{client[:name]}"
  end
end
```

**重要**: Elkのredirect_uriの`[YOUR_DOMAIN]`部分は実際のドメインに置き換えてください。

### 5. URLエンコーディングの注意点

特にElkでは、redirect_uriが複雑にエンコードされているため、実際のリクエストで送信される形式と完全に一致させる必要があります。

**Elkの実際のredirect_uri形式**:
```
https://elk.zone/api/agricultural-proceedings-surprise-manhattan.trycloudflare.com/oauth/https%3A%2F%2Felk.zone
```

### 6. インスタンス情報の設定

Mastodonクライアントが期待する形式でインスタンス情報を返すよう設定：

```ruby
# app/controllers/api/v1/instance_controller.rb
def instance_info
  {
    uri: local_domain,
    title: 'letter',
    version: '0.1.0 (compatible; letter 0.1.0)',
    # その他のフィールド...
  }
end
```

## テスト済みクライアント

| クライアント | 自動登録 | 事前作成 | 状態 |
|-------------|----------|----------|------|
| Pinafore    | ✅       | -        | 完全動作 |
| Elk         | ❌       | ✅       | 完全動作 |
| Phanpy      | ❌       | ✅       | 完全動作 |

## 今後の対応

新しいクライアントをテストする際は：

1. まず自動アプリケーション登録が機能するかテスト
2. 失敗した場合は、ログから固定credentials情報を抽出
3. 必要に応じてデフォルトアプリケーションを追加

## 注意事項

- ElkとPhanpyが自動アプリケーション登録を行わない根本原因は未解明
- トンネルドメインや開発環境検出が関係している可能性
- 本番環境では異なる動作をする可能性がある
