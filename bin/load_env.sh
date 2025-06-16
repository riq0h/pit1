#!/bin/bash

# 環境変数読み込みヘルパー
# 使用法: source bin/load_env.sh

load_env_vars() {
    if [ ! -f .env ]; then
        echo "ERROR: .env file not found"
        return 1
    fi
    
    set -a
    source .env
    set +a
    
    # 必須環境変数のチェック
    if [ -z "$ACTIVITYPUB_DOMAIN" ]; then
        echo "ERROR: ACTIVITYPUB_DOMAIN not set in .env"
        return 1
    fi
    
    if [ -z "$ACTIVITYPUB_PROTOCOL" ]; then
        echo "WARNING: ACTIVITYPUB_PROTOCOL not set, defaulting to https"
        export ACTIVITYPUB_PROTOCOL="https"
    fi
    
    echo "✓ Environment variables loaded:"
    echo "  ACTIVITYPUB_DOMAIN: $ACTIVITYPUB_DOMAIN"
    echo "  ACTIVITYPUB_PROTOCOL: $ACTIVITYPUB_PROTOCOL"
    echo "  BASE_URL: $ACTIVITYPUB_PROTOCOL://$ACTIVITYPUB_DOMAIN"
}

# Rails runnerのラッパー関数
run_with_env() {
    load_env_vars >/dev/null || return 1
    
    ACTIVITYPUB_DOMAIN="$ACTIVITYPUB_DOMAIN" \
    ACTIVITYPUB_PROTOCOL="$ACTIVITYPUB_PROTOCOL" \
    rails runner "$@"
}

# 自動読み込み（sourceされた場合）
if [ "${BASH_SOURCE[0]}" != "${0}" ]; then
    load_env_vars
fi