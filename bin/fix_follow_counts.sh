#!/bin/bash

# Letter ActivityPub Instance - Follow Count Fix Script
# フォローカウント修正スクリプト

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

# Main function
main() {
    print_header "Letter ActivityPub フォローカウント修正"
    
    print_info "現在のフォローカウントを確認しています..."
    echo ""
    
    # 現在の状態を表示
    rails runner "
    puts '=== 現在の状態 ==='
    Actor.where(local: true).each do |actor|
      following_count = Follow.where(actor: actor, accepted: true).count
      followers_count = Follow.where(target_actor: actor, accepted: true).count
      
      puts \"#{actor.username}:\"
      puts \"  DBのフォロー数: #{actor.following_count} (実際: #{following_count})\"
      puts \"  DBのフォロワー数: #{actor.followers_count} (実際: #{followers_count})\"
      puts \"  修正が必要: #{actor.following_count != following_count || actor.followers_count != followers_count}\"
      puts
    end
    "
    
    echo ""
    read -p "フォローカウントを修正しますか? (y/N): " confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "操作をキャンセルしました"
        exit 0
    fi
    
    echo ""
    print_info "フォローカウントを修正中..."
    
    # カウント修正
    rails runner "
    fixed_count = 0
    Actor.where(local: true).each do |actor|
      following_count = Follow.where(actor: actor, accepted: true).count
      followers_count = Follow.where(target_actor: actor, accepted: true).count
      
      if actor.following_count != following_count || actor.followers_count != followers_count
        puts \"#{actor.username}を修正: フォロー数 #{actor.following_count} -> #{following_count}, フォロワー数 #{actor.followers_count} -> #{followers_count}\"
        actor.update!(following_count: following_count, followers_count: followers_count)
        fixed_count += 1
      else
        puts \"#{actor.username}: カウントは正確です\"
      end
    end
    
    puts \"\"
    puts \"#{fixed_count}個のアクターを修正しました\"
    "
    
    echo ""
    print_success "フォローカウント修正が完了しました!"
}

# Run main function
main "$@"