#!/bin/bash

echo "=== VAPID キーペア生成スクリプト ==="
echo ""

# 一時ファイル名
PRIVATE_KEY_FILE="vapid_private_key.pem"
PUBLIC_KEY_FILE="vapid_public_key.pem"

# 秘密鍵を生成 (P-256楕円曲線)
echo "1. 秘密鍵を生成中..."
openssl ecparam -genkey -name prime256v1 -noout -out "$PRIVATE_KEY_FILE"

# 公開鍵を生成
echo "2. 公開鍵を生成中..."
openssl ec -in "$PRIVATE_KEY_FILE" -pubout -out "$PUBLIC_KEY_FILE"

# Base64エンコード（URLセーフ）でキーを抽出
echo "3. キーをBase64エンコード中..."

# 秘密鍵をBase64 URLセーフ形式で抽出
PRIVATE_KEY_B64=$(openssl ec -in "$PRIVATE_KEY_FILE" -noout -text | grep priv: -A 3 | tail -n +2 | tr -d '[:space:]:' | xxd -r -p | base64 | tr '+/' '-_' | tr -d '=')

# 公開鍵をBase64 URLセーフ形式で抽出
PUBLIC_KEY_B64=$(openssl ec -in "$PUBLIC_KEY_FILE" -noout -text | grep pub: -A 5 | tail -n +2 | tr -d '[:space:]:' | xxd -r -p | tail -c +2 | base64 | tr '+/' '-_' | tr -d '=')

echo ""
echo "=== 生成されたVAPIDキーペア ==="
echo "VAPID_PUBLIC_KEY=$PUBLIC_KEY_B64"
echo "VAPID_PRIVATE_KEY=$PRIVATE_KEY_B64"
echo ""

echo "=== .envファイルへの追加 ==="
echo "以下の行を .env ファイルに追加または更新してください："
echo ""
echo "VAPID_PUBLIC_KEY=$PUBLIC_KEY_B64"
echo "VAPID_PRIVATE_KEY=$PRIVATE_KEY_B64"
echo ""

# 既存の.envファイルがある場合、バックアップを作成して更新
if [ -f ".env" ]; then
    echo "既存の.envファイルを更新しますか？ (y/N)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        # バックアップを作成
        cp .env .env.backup
        echo ".envファイルのバックアップを作成しました: .env.backup"
        
        # 既存のVAPIDキーを削除
        sed -i '/^VAPID_PUBLIC_KEY=/d' .env
        sed -i '/^VAPID_PRIVATE_KEY=/d' .env
        
        # 新しいキーを追加
        echo "VAPID_PUBLIC_KEY=$PUBLIC_KEY_B64" >> .env
        echo "VAPID_PRIVATE_KEY=$PRIVATE_KEY_B64" >> .env
        
        echo "✅ .envファイルを更新しました"
    fi
fi

# 一時ファイルを削除
rm -f "$PRIVATE_KEY_FILE" "$PUBLIC_KEY_FILE"

echo ""
echo "=== 注意事項 ==="
echo "- VAPIDキーを変更すると、既存のプッシュ通知サブスクリプションは無効になります"
echo "- サーバを再起動して新しいキーを適用してください"
echo "- これらのキーは安全に保管してください"
