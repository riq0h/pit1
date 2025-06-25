#!/bin/bash

# Letter ActivityPub Instance - Domain Configuration Check Script
# ドメイン設定確認スクリプト

set -e

# デバッグモードの確認
DEBUG_MODE=false
if [ "$1" = "--debug" ] || [ "$1" = "-d" ]; then
    DEBUG_MODE=true
    echo "🔍 デバッグモードが有効です"
fi

# スクリプトのディレクトリとプロジェクトルートを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 相対パスが正しく動作するようプロジェクトルートに移動
cd "$PROJECT_ROOT"

# 環境変数を読み込み
source bin/load_env.sh

# 出力用の色設定
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# カラー出力用関数
print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

print_error() {
    echo -e "${RED}❌${NC} $1"
}

print_info() {
    echo -e "${CYAN}ℹ️${NC} $1"
}

print_debug() {
    if [ "$DEBUG_MODE" = true ]; then
        echo -e "${YELLOW}🔍${NC} [DEBUG] $1"
    fi
}

print_header "Letter ActivityPub ドメイン設定確認"

# .envファイルをチェック
if [ -f .env ]; then
    DOMAIN=$(grep "^ACTIVITYPUB_DOMAIN=" .env | cut -d'=' -f2)
    PROTOCOL=$(grep "^ACTIVITYPUB_PROTOCOL=" .env | cut -d'=' -f2)
    
    print_info "環境設定:"
    echo "  ドメイン: $DOMAIN"
    echo "  プロトコル: $PROTOCOL"
    echo "  ベースURL: $PROTOCOL://$DOMAIN"
else
    print_warning ".envファイルが見つかりません"
fi

# サーバが動作しているかチェック
echo ""
print_info "サーバ状態チェック中..."

# 環境変数の確認
print_info "環境変数チェック:"
echo "  ACTIVITYPUB_PROTOCOL: ${ACTIVITYPUB_PROTOCOL:-'未設定'}"
echo "  ACTIVITYPUB_DOMAIN: ${ACTIVITYPUB_DOMAIN:-'未設定'}"

# より幅広いパターンでRailsプロセスをチェック
RAILS_PATTERNS=(
    "rails server"
    "rails s"
    "bin/rails server"
    "bin/rails s"
    "puma"
    "bundle exec rails server"
    "bundle exec rails s"
    "bundle exec puma"
)

SERVER_RUNNING=false
DETECTED_PROCESS=""

for pattern in "${RAILS_PATTERNS[@]}"; do
    print_debug "プロセスパターン検索: '$pattern'"
    if pgrep -f "$pattern" > /dev/null 2>&1; then
        SERVER_RUNNING=true
        DETECTED_PROCESS="$pattern"
        print_debug "マッチしたパターン: '$pattern'"
        break
    fi
done

print_debug "プロセス検索結果: SERVER_RUNNING=$SERVER_RUNNING"

if [ "$SERVER_RUNNING" = true ]; then
    print_info "検出されたプロセス: $DETECTED_PROCESS"
    
    # プロセス詳細を表示
    PROCESS_INFO=$(ps aux | grep -E "(rails|puma)" | grep -v grep | head -3)
    if [ -n "$PROCESS_INFO" ]; then
        echo "  アクティブなプロセス:"
        echo "$PROCESS_INFO" | while IFS= read -r line; do
            echo "    $line"
        done
    fi
    
    # 複数のURLパターンでHTTP接続テスト
    HTTP_SUCCESS=false
    
    # パターン1: 設定されたドメインとプロトコル
    if [ -n "$ACTIVITYPUB_PROTOCOL" ] && [ -n "$ACTIVITYPUB_DOMAIN" ]; then
        print_info "テスト1: $ACTIVITYPUB_PROTOCOL://$ACTIVITYPUB_DOMAIN"
        print_debug "curl実行: curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 '$ACTIVITYPUB_PROTOCOL://$ACTIVITYPUB_DOMAIN'"
        server_response=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$ACTIVITYPUB_PROTOCOL://$ACTIVITYPUB_DOMAIN" 2>/dev/null || echo "000")
        echo "  レスポンスコード: $server_response"
        if [ "$server_response" = "200" ] || [ "$server_response" = "302" ] || [ "$server_response" = "301" ]; then
            HTTP_SUCCESS=true
            print_debug "HTTP接続成功: テスト1"
        fi
    fi
    
    # パターン2: localhost:3000での直接テスト
    if [ "$HTTP_SUCCESS" = false ]; then
        print_info "テスト2: http://localhost:3000"
        print_debug "curl実行: curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 'http://localhost:3000'"
        local_response=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "http://localhost:3000" 2>/dev/null || echo "000")
        echo "  レスポンスコード: $local_response"
        if [ "$local_response" = "200" ] || [ "$local_response" = "302" ] || [ "$local_response" = "301" ]; then
            HTTP_SUCCESS=true
            print_info "ローカル接続が利用可能です"
            print_debug "HTTP接続成功: テスト2"
        fi
    fi
    
    # パターン3: 127.0.0.1:3000での直接テスト
    if [ "$HTTP_SUCCESS" = false ]; then
        print_info "テスト3: http://127.0.0.1:3000"
        print_debug "curl実行: curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 'http://127.0.0.1:3000'"
        ip_response=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "http://127.0.0.1:3000" 2>/dev/null || echo "000")
        echo "  レスポンスコード: $ip_response"
        if [ "$ip_response" = "200" ] || [ "$ip_response" = "302" ] || [ "$ip_response" = "301" ]; then
            HTTP_SUCCESS=true
            print_info "IP直接接続が利用可能です"
            print_debug "HTTP接続成功: テスト3"
        fi
    fi
    
    # 結果の表示
    if [ "$HTTP_SUCCESS" = true ]; then
        print_success "サーバ状態: 動作中 (プロセス検出済み・HTTP応答確認済み)"
    else
        print_warning "サーバ状態: プロセス動作中だがHTTP応答なし"
        echo "  プロセスは検出されましたが、HTTP接続に失敗しました"
        echo "  - 設定されたドメイン: ${ACTIVITYPUB_DOMAIN:-'未設定'}"
        echo "  - ローカル接続も失敗しました"
        echo "  - サーバが完全に起動していない可能性があります"
    fi
    
    # ローカルユーザのリストを取得
    echo ""
    print_info "ローカルユーザ:"
    LOCAL_USERS=$(rails runner "Actor.where(local: true).pluck(:username).each { |u| puts u }" 2>/dev/null)
    if [ -n "$LOCAL_USERS" ]; then
        echo "$LOCAL_USERS" | while read -r username; do
            if [ -n "$username" ]; then
                echo "  - $username"
            fi
        done
        
        # 最初のユーザでエンドポイントをテスト
        FIRST_USER=$(echo "$LOCAL_USERS" | head -1)
        if [ -n "$FIRST_USER" ]; then
            echo ""
            print_info "エンドポイントテスト ($FIRST_USER を使用):"
            
            # Actorエンドポイントをテスト
            ACTOR_RESPONSE=$(curl -s -H "Accept: application/activity+json" "$ACTIVITYPUB_PROTOCOL://$ACTIVITYPUB_DOMAIN/users/$FIRST_USER" | jq -r '.id' 2>/dev/null)
            if [ "$ACTOR_RESPONSE" != "null" ] && [ -n "$ACTOR_RESPONSE" ]; then
                echo "  Actor ID: $ACTOR_RESPONSE"
            else
                echo "  Actor ID: エンドポイントアクセスエラー"
            fi
            
            # WebFingerをテスト
            WEBFINGER_RESPONSE=$(curl -s "$ACTIVITYPUB_PROTOCOL://$ACTIVITYPUB_DOMAIN/.well-known/webfinger?resource=acct:$FIRST_USER@$ACTIVITYPUB_DOMAIN" | jq -r '.subject' 2>/dev/null)
            if [ "$WEBFINGER_RESPONSE" != "null" ] && [ -n "$WEBFINGER_RESPONSE" ]; then
                echo "  WebFinger: $WEBFINGER_RESPONSE"
            else
                echo "  WebFinger: エンドポイントアクセスエラー"
            fi
        fi
    else
        echo "  ローカルユーザが見つかりません"
        echo "  次のコマンドでユーザを作成してください: ./bin/manage_accounts.sh"
    fi
    
    # データベース統計をチェック
    echo ""
    print_info "データベース統計:"
    rails runner "
      puts '  ローカルアクター数: ' + Actor.where(local: true).count.to_s
      puts '  リモートアクター数: ' + Actor.where(local: false).count.to_s
      puts '  投稿総数: ' + ActivityPubObject.count.to_s
      puts '  フォロー関係数: ' + Follow.count.to_s
      puts '  OAuthアプリケーション数: ' + Doorkeeper::Application.count.to_s
      puts '  アクセストークン数: ' + Doorkeeper::AccessToken.count.to_s
    " 2>/dev/null || echo "  データベースアクセスエラー"
    
else
    print_warning "サーバ状態: 停止中"
fi

# プロセス情報を表示
echo ""
print_info "詳細プロセス情報:"

# Rails/Pumaプロセスの詳細検索
RAILS_FOUND=false
for pattern in "${RAILS_PATTERNS[@]}"; do
    PROCS=$(pgrep -f "$pattern" 2>/dev/null || echo "")
    if [ -n "$PROCS" ]; then
        RAILS_FOUND=true
        PROC_COUNT=$(echo "$PROCS" | wc -l)
        echo "  パターン '$pattern': $PROC_COUNT プロセス"
        echo "$PROCS" | while read -r pid; do
            if [ -n "$pid" ]; then
                PROC_INFO=$(ps -p "$pid" -o pid,ppid,user,cmd --no-headers 2>/dev/null || echo "PID $pid: 情報取得不可")
                echo "    PID $pid: $PROC_INFO"
            fi
        done
    fi
done

if [ "$RAILS_FOUND" = false ]; then
    echo "  Rails/Pumaプロセスが見つかりません"
    
    # 類似プロセスを検索
    echo "  類似プロセス検索:"
    SIMILAR_PROCS=$(ps aux | grep -E "(ruby|rails|puma|bundle)" | grep -v grep | head -5)
    if [ -n "$SIMILAR_PROCS" ]; then
        echo "$SIMILAR_PROCS" | while IFS= read -r line; do
            echo "    $line"
        done
    else
        echo "    関連プロセスが見つかりません"
    fi
fi

# Solid Queueプロセス
QUEUE_PROCS=$(pgrep -f "solid.*queue" 2>/dev/null | wc -l || echo "0")
echo "  Solid Queueプロセス数: $QUEUE_PROCS"
if [ "$QUEUE_PROCS" -gt 0 ]; then
    QUEUE_PIDS=$(pgrep -f "solid.*queue" | tr '\n' ' ')
    echo "  Queue PID: $QUEUE_PIDS"
fi

# ポート使用状況
echo ""
print_info "ポート使用状況:"
PORT_3000=$(netstat -tlnp 2>/dev/null | grep ":3000 " || echo "")
if [ -n "$PORT_3000" ]; then
    echo "  ポート3000:"
    echo "$PORT_3000" | while IFS= read -r line; do
        echo "    $line"
    done
else
    echo "  ポート3000: 使用されていません"
fi

# 最近のドメイン履歴を表示
echo ""
print_info "最近のドメイン履歴:"
if [ -f .env ]; then
    grep "^# -" .env | tail -5 | sed 's/^# - /  /' 2>/dev/null || echo "  履歴エントリが見つかりません"
else
    echo "  履歴は利用できません"
fi
