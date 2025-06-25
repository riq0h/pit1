#!/bin/bash

# Dockerクイックスタート
# このスクリプトはDockerで素早くセットアップして実行するのに役立ちます

set -e

echo "🚀 Dockerクイックスタート"
echo "=================================================="
echo ""

# Dockerがインストールされているかチェック
if ! command -v docker &> /dev/null; then
    echo "❌ Dockerがインストールされていません。まずDockerをインストールしてください。"
    echo "訪問先: https://docs.docker.com/get-docker/"
    exit 1
fi

# Docker Composeがインストールされているかチェック
if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Composeがインストールされていません。まずDocker Composeをインストールしてください。"
    echo "訪問先: https://docs.docker.com/compose/install/"
    exit 1
fi

echo "✅ DockerとDocker Composeがインストールされています"
echo ""

# 環境ファイルが存在しない場合は作成
if [ ! -f ".env.docker.local" ]; then
    echo "📝 環境設定を作成中..."
    cp .env.docker .env.docker.local
    
    echo "⚙️  .env.docker.localで設定を構成してください"
    echo "最低限、ACTIVITYPUB_DOMAINを設定してください"
    echo ""
    read -p "ドメインを入力してください (localhost:3000の場合はEnterを押してください): " domain
    
    if [ -n "$domain" ]; then
        sed -i "s/ACTIVITYPUB_DOMAIN=localhost:3000/ACTIVITYPUB_DOMAIN=$domain/" .env.docker.local
        
        if [[ $domain != *"localhost"* ]]; then
            sed -i "s/ACTIVITYPUB_PROTOCOL=http/ACTIVITYPUB_PROTOCOL=https/" .env.docker.local
        fi
    fi
    
    echo "✅ 環境ファイルが作成されました: .env.docker.local"
else
    echo "✅ 環境ファイルが存在します: .env.docker.local"
fi

echo ""

# 必要なディレクトリを作成
echo "📁 必要なディレクトリを作成中..."
mkdir -p db log public/system/accounts/avatars public/system/accounts/headers public/system/media_attachments
echo "✅ ディレクトリが作成されました"
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
        echo "🔨 Building and starting Letter..."
        docker-compose up --build
        ;;
    2)
        echo "🔨 Building and starting Letter in background..."
        docker-compose up -d --build
        echo ""
        echo "✅ Letter is running in background"
        echo "🌐 Access your instance at: http://localhost:3000"
        echo "📊 Health check: http://localhost:3000/up"
        echo ""
        echo "📝 Useful commands:"
        echo "  View logs: docker-compose logs -f"
        echo "  Stop: docker-compose down"
        echo "  Restart: docker-compose restart"
        ;;
    3)
        echo "🔨 Building Letter..."
        docker-compose build
        echo "✅ Build completed"
        ;;
    4)
        echo "📜 Viewing logs..."
        docker-compose logs -f
        ;;
    5)
        echo "🛑 Stopping Letter..."
        docker-compose down
        echo "✅ Letter stopped"
        ;;
    6)
        echo "🧹 Cleaning up..."
        docker-compose down --rmi all --volumes --remove-orphans
        echo "✅ Cleanup completed"
        ;;
    *)
        echo "❌ Invalid choice. Please run the script again."
        exit 1
        ;;
esac

echo ""
echo "📚 For more information, see DOCKER.md"
echo "🎉 Happy federating!"