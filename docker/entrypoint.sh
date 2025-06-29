#!/bin/bash
set -e

# Dockerエントリーポイント
# データベースセットアップ、環境検証、プロセス管理を処理

echo "=== アプリケーション開始 ==="

# 依存関係の待機関数
wait_for_dependencies() {
    echo "依存関係をチェック中..."
    # 必要に応じてデータベース接続チェックを追加
    echo "OK: 依存関係準備完了"
}

# 必要な環境変数を検証
validate_environment() {
    echo "環境変数を検証中..."
    
    if [ -z "$ACTIVITYPUB_DOMAIN" ]; then
        echo "ERROR: ACTIVITYPUB_DOMAINが必要です"
        echo "docker-compose.ymlまたは.envファイルでACTIVITYPUB_DOMAINを設定してください"
        exit 1
    fi
    
    if [ -z "$ACTIVITYPUB_PROTOCOL" ]; then
        echo "WARNING: ACTIVITYPUB_PROTOCOLが設定されていません、httpsをデフォルトとします"
        export ACTIVITYPUB_PROTOCOL=https
    fi
    
    echo "OK: 環境変数検証完了"
    echo "  ドメイン: $ACTIVITYPUB_DOMAIN"
    echo "  プロトコル: $ACTIVITYPUB_PROTOCOL"
}

# データベースセットアップ
setup_database() {
    echo "データベースをセットアップ中..."
    
    # データベースが存在するかチェック  
    RAILS_ENV=${RAILS_ENV:-development}
    DB_FILE="storage/${RAILS_ENV}.sqlite3"
    if [ ! -f "$DB_FILE" ]; then
        echo "データベースを作成中..."
        bundle exec rails db:create
        bundle exec rails db:migrate
        echo "OK: データベース作成とマイグレーション完了"
    else
        echo "データベースが存在します、マイグレーションを実行中..."
        bundle exec rails db:migrate
        echo "OK: データベースマイグレーション完了"
    fi
}

# 必要に応じてアセットをプリコンパイル
prepare_assets() {
    echo "アセットを準備中..."
    
    # 本番環境またはアセットが存在しない場合のみプリコンパイル
    if [ "$RAILS_ENV" = "production" ] || [ ! -d "public/assets" ]; then
        echo "アセットをプリコンパイル中..."
        bundle exec rails assets:precompile
        echo "OK: アセットプリコンパイル完了"
    else
        echo "OK: アセットは既に準備済み"
    fi
}

# 古いプロセスをクリーンアップ
cleanup_processes() {
    echo "プロセスをクリーンアップ中..."
    
    # PIDファイルを削除
    rm -f tmp/pids/server.pid
    rm -f tmp/pids/solid_queue.pid
    
    echo "OK: プロセスクリーンアップ完了"
}

# Solid Queueをバックグラウンドで開始
start_solid_queue() {
    echo "Solid Queueワーカーを開始中..."
    
    # Solid Queueをバックグラウンドプロセスとして開始
    bundle exec bin/jobs &
    SOLID_QUEUE_PID=$!
    echo $SOLID_QUEUE_PID > tmp/pids/solid_queue.pid
    
    echo "OK: Solid Queue開始 (PID: $SOLID_QUEUE_PID)"
}

# グレースフルシャットダウンハンドラー
shutdown_handler() {
    echo ""
    echo "=== アプリケーション終了中 ==="
    
    # Solid Queueを停止
    if [ -f tmp/pids/solid_queue.pid ]; then
        SOLID_QUEUE_PID=$(cat tmp/pids/solid_queue.pid)
        if kill -0 $SOLID_QUEUE_PID 2>/dev/null; then
            echo "Solid Queue停止中 (PID: $SOLID_QUEUE_PID)..."
            kill -TERM $SOLID_QUEUE_PID
            wait $SOLID_QUEUE_PID 2>/dev/null || true
        fi
        rm -f tmp/pids/solid_queue.pid
    fi
    
    echo "OK: グレースフルシャットダウン完了"
    exit 0
}

# シグナルハンドラーを設定
trap shutdown_handler SIGTERM SIGINT

# メイン実行
main() {
    wait_for_dependencies
    validate_environment
    cleanup_processes
    setup_database
    prepare_assets
    start_solid_queue
    
    echo "=== アプリケーション準備完了 ==="
    echo "Railsサーバを開始中..."
    echo "アクセス可能: $ACTIVITYPUB_PROTOCOL://$ACTIVITYPUB_DOMAIN"
    echo ""
    
    # メインコマンドを実行
    exec "$@"
}

# メイン関数を実行
main "$@"
