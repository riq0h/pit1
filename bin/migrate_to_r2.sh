#!/bin/bash

# Letter ActivityPub Instance - Cloudflare R2 Migration Script
# ローカルストレージの画像をCloudflare R2に移行します

set -e

# Get the directory of this script and the project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Change to project root to ensure relative paths work
cd "$PROJECT_ROOT"

# Load environment variables
source bin/load_env.sh

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
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

print_header "Letter ActivityPub - Cloudflare R2 移行"
echo ""

# Check if R2 is enabled
if [[ "$S3_ENABLED" != "true" ]]; then
    print_error "Cloudflare R2が無効になっています"
    print_info "移行を実行するには、.envファイルでS3_ENABLED=trueに設定してください"
    exit 1
fi

# Check required R2 configuration
missing_config=false

if [[ -z "$S3_ENDPOINT" ]]; then
    print_error "S3_ENDPOINTが設定されていません"
    missing_config=true
fi

if [[ -z "$S3_BUCKET" ]]; then
    print_error "S3_BUCKETが設定されていません"
    missing_config=true
fi

if [[ -z "$R2_ACCESS_KEY_ID" ]]; then
    print_error "R2_ACCESS_KEY_IDが設定されていません"
    missing_config=true
fi

if [[ -z "$R2_SECRET_ACCESS_KEY" ]]; then
    print_error "R2_SECRET_ACCESS_KEYが設定されていません"
    missing_config=true
fi

if [[ "$missing_config" == "true" ]]; then
    print_info "設定を確認してから再度実行してください"
    exit 1
fi

print_success "Cloudflare R2設定確認完了"
echo ""
print_info "エンドポイント: $S3_ENDPOINT"
print_info "バケット: $S3_BUCKET"
echo ""

# Get migration statistics
print_info "現在のファイル状況を確認中..."

migration_stats=$(run_with_env "
require 'stringio'

def count_local_attachments(model, attachment_name)
  join_condition = if model.name == 'CustomEmoji'
    'INNER JOIN active_storage_attachments ON active_storage_attachments.record_id = ' + model.table_name + '.id'
  else
    'INNER JOIN active_storage_attachments ON CAST(active_storage_attachments.record_id AS TEXT) = CAST(' + model.table_name + '.id AS TEXT)'
  end
  
  model.joins(join_condition)
       .joins('INNER JOIN active_storage_blobs ON active_storage_blobs.id = active_storage_attachments.blob_id')
       .where(active_storage_attachments: { 
         record_type: model.name, 
         name: attachment_name 
       })
       .where(active_storage_blobs: { service_name: ['local', nil] })
       .count
end

def count_local_actor_attachments(attachment_name)
  Actor.joins('INNER JOIN active_storage_attachments ON active_storage_attachments.record_id = actors.id')
       .joins('INNER JOIN active_storage_blobs ON active_storage_blobs.id = active_storage_attachments.blob_id')
       .where(active_storage_attachments: { 
         record_type: 'Actor', 
         name: attachment_name 
       })
       .where(active_storage_blobs: { service_name: ['local', nil] })
       .count
end

media_attachments = count_local_attachments(MediaAttachment, 'file')
custom_emojis = count_local_attachments(CustomEmoji, 'image')
actor_avatars = count_local_actor_attachments('avatar')
actor_headers = count_local_actor_attachments('header')
total_local = ActiveStorage::Blob.where(service_name: ['local', nil]).count
total_r2 = ActiveStorage::Blob.where(service_name: 'cloudflare_r2').count

puts \"media_attachments|#{media_attachments}\"
puts \"custom_emojis|#{custom_emojis}\"
puts \"actor_avatars|#{actor_avatars}\"
puts \"actor_headers|#{actor_headers}\"
puts \"total_local|#{total_local}\"
puts \"total_r2|#{total_r2}\"
")

# Parse migration statistics
media_count=$(echo "$migration_stats" | grep "^media_attachments" | cut -d'|' -f2)
emoji_count=$(echo "$migration_stats" | grep "^custom_emojis" | cut -d'|' -f2)
avatar_count=$(echo "$migration_stats" | grep "^actor_avatars" | cut -d'|' -f2)
header_count=$(echo "$migration_stats" | grep "^actor_headers" | cut -d'|' -f2)
local_total=$(echo "$migration_stats" | grep "^total_local" | cut -d'|' -f2)
r2_total=$(echo "$migration_stats" | grep "^total_r2" | cut -d'|' -f2)

echo ""
print_info "ファイル状況:"
echo "  メディア添付ファイル（ローカル）: $media_count"
echo "  カスタム絵文字（ローカル）: $emoji_count"
echo "  ユーザアバター（ローカル）: $avatar_count"
echo "  ユーザヘッダー（ローカル）: $header_count"
echo "  ローカル合計: $local_total"
echo "  R2合計: $r2_total"
echo ""

if [[ "$local_total" -eq 0 ]]; then
    print_success "移行対象のローカルファイルはありません"
    exit 0
fi

# Confirm migration
echo -n "これらのファイルをCloudflare R2に移行しますか？ [y/N]: "
read -r confirmation

if [[ ! "$confirmation" =~ ^[Yy]$ ]]; then
    print_info "移行をキャンセルしました"
    exit 0
fi

echo ""

# Get batch size
while true; do
    echo -n "バッチサイズを入力してください (10-200, デフォルト: 50): "
    read -r batch_size
    
    if [[ -z "$batch_size" ]]; then
        batch_size=50
        break
    fi
    
    if [[ "$batch_size" =~ ^[0-9]+$ ]] && [[ "$batch_size" -ge 10 ]] && [[ "$batch_size" -le 200 ]]; then
        break
    else
        print_error "10から200の間の数値を入力してください"
    fi
done

echo ""
print_info "バッチサイズ: $batch_size でR2への移行を開始します..."

# Execute migration
migration_result=$(run_with_env "
begin
  MigrateToR2Job.perform_now(batch_size: $batch_size)
  puts 'success|移行が正常に完了しました'
rescue => e
  puts \"error|移行に失敗しました: #{e.message}\"
  exit 1
end
")

status=$(echo "$migration_result" | grep "^success\|^error" | head -1 | cut -d'|' -f1)
message=$(echo "$migration_result" | grep "^success\|^error" | head -1 | cut -d'|' -f2)

echo ""

if [[ "$status" == "success" ]]; then
    print_success "$message"
    
    # Get final statistics
    final_stats=$(run_with_env "
    total_local = ActiveStorage::Blob.where(service_name: ['local', nil]).count
    total_r2 = ActiveStorage::Blob.where(service_name: 'cloudflare_r2').count
    puts \"total_local|#{total_local}\"
    puts \"total_r2|#{total_r2}\"
    ")
    
    final_local=$(echo "$final_stats" | grep "^total_local" | cut -d'|' -f2)
    final_r2=$(echo "$final_stats" | grep "^total_r2" | cut -d'|' -f2)
    
    echo ""
    print_info "移行後の状況:"
    echo "  ローカル: $final_local"
    echo "  R2: $final_r2"
    
else
    print_error "$message"
    exit 1
fi

echo ""
print_header "Cloudflare R2 移行完了"