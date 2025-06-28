#!/bin/bash

# Dockerクイックスタート
# このスクリプトはDockerで素早くセットアップして実行するのに役立ちます

set -e

echo "letter - Dockerクイックスタート"
echo "=================================================="
echo ""

# Dockerがインストールされているかチェック
if ! command -v docker &> /dev/null; then
    echo "ERROR: Dockerがインストールされていません。まずDockerをインストールしてください。"
    echo "参考: https://docs.docker.com/get-docker/"
    exit 1
fi

# Docker Composeがインストールされているかチェック
if ! command -v docker-compose &> /dev/null; then
    echo "ERROR: Docker Composeがインストールされていません。まずDocker Composeをインストールしてください。"
    echo "参考: https://docs.docker.com/compose/install/"
    exit 1
fi

echo "OK: DockerとDocker Composeがインストールされています"
echo ""

# 環境ファイルが存在しない場合は作成
if [ ! -f ".env" ]; then
    echo "INFO: 環境設定を作成中..."
    echo "INFO: .envファイルを作成してください"
    echo "最低限、ACTIVITYPUB_DOMAINを設定してください"
    echo ""
    read -p "ドメインを入力してください (localhost:3000の場合はEnterを押してください): " domain
    
    domain=${domain:-localhost:3000}
    protocol="http"
    
    if [[ $domain != *"localhost"* ]]; then
        protocol="https"
    fi
    
    cat > .env << EOF
# ActivityPub設定
ACTIVITYPUB_DOMAIN=$domain
ACTIVITYPUB_PROTOCOL=$protocol

# インスタンス設定
INSTANCE_NAME=letter
INSTANCE_DESCRIPTION=General letter Publication System based on ActivityPub

# Cloudflare R2オブジェクトストレージ設定
S3_ENABLED=false
S3_ENDPOINT=
S3_BUCKET=
R2_ACCESS_KEY_ID=
R2_SECRET_ACCESS_KEY=
S3_ALIAS_HOST=

# Rails設定
RAILS_ENV=development
EOF
    
    echo "OK: 環境ファイルが作成されました: .env"
else
    echo "OK: 環境ファイルが存在します: .env"
fi

echo ""

# 必要なディレクトリを作成
echo "INFO: 必要なディレクトリを作成中..."
mkdir -p storage log
echo "OK: ディレクトリが作成されました"
echo ""

# ユーザに何をするか尋ねる
echo "何をしますか？"
echo "1) ビルドしてアプリを開始（フォアグラウンド）"
echo "2) アプリをバックグラウンドで開始"
echo "3) ビルドのみ（開始しない）"
echo "4) ログを表示"
echo "5) アプリを停止"
echo "6) クリーンアップ（コンテナとイメージを削除）"
echo ""
read -p "選択してください (1-6): " choice

case $choice in
    1)
        echo "INFO: letterをビルドして開始中..."
        docker-compose up --build
        ;;
    2)
        echo "INFO: letterをバックグラウンドでビルドして開始中..."
        docker-compose up -d --build
        echo ""
        echo "OK: letterがバックグラウンドで実行中です"
        echo "アクセス: http://localhost:3000"
        echo "ヘルスチェック: http://localhost:3000/up"
        echo ""
        echo "便利なコマンド:"
        echo "  ログ表示: docker-compose logs -f"
        echo "  停止: docker-compose down"
        echo "  再起動: docker-compose restart"
        ;;
    3)
        echo "INFO: letterをビルド中..."
        docker-compose build
        echo "OK: ビルドが完了しました"
        ;;
    4)
        echo "INFO: ログを表示中..."
        docker-compose logs -f
        ;;
    5)
        echo "INFO: letterを停止中..."
        docker-compose down
        echo "OK: letterが停止しました"
        ;;
    6)
        echo "INFO: クリーンアップ中..."
        docker-compose down --rmi all --volumes --remove-orphans
        echo "OK: クリーンアップが完了しました"
        ;;
    *)
        echo "ERROR: 無効な選択です。スクリプトを再実行してください。"
        exit 1
        ;;
esac

echo ""
echo "詳細については DOCKER.md を参照してください"