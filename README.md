# letter : General Letter Publication System based on ActivityPub / 一般書簡公衆化システム

letterはRails8およびSQLite、Hotwireで構成されるミニマルなActivityPub実装であり、一般的に作成された電子書簡を速やかに公衆送信することができます。この実装系は以下の特徴を備えています。

・1インスタンス2アカウント制限  
・サードパーティクライアントの利用を前提とした軽量な設計  
・RedisやSidekiqを廃し、Solid QueueおよびSolid Cableで構成された外部非依存のバックエンド  
・マイクロブログの復権を意識した平易かつ高速なフロントエンド  
・Rails8のデフォルトに基づき、SQLiteを本番環境で使用
・ローカル投稿の全文検索に対応  
・Mastodon APIに準拠

## セットアップ

```
RAILS_ENV=production bin/setup
```

## 管理ツール

```
bin/letter_manager.rb
```
