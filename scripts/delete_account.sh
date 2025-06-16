#!/bin/bash

# Letter ActivityPub Instance - Account Deletion Script
# Deletes accounts with all dependent records

set -e

# Get the directory of this script and the project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Change to project root to ensure relative paths work
cd "$PROJECT_ROOT"

# Load environment variables
source scripts/load_env.sh

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

# Function to delete an actor by ID or username
delete_actor() {
    local identifier="$1"
    
    # Ruby script to delete an actor
    deletion_result=$(run_with_env "
    begin
      # Find actor by ID or username
      if '$identifier'.match?(/^\\d+$/)
        actor = Actor.find_by(id: '$identifier')
      else
        actor = Actor.find_by(username: '$identifier', local: true)
      end
      
      unless actor
        puts 'not_found'
        puts 'アカウントが見つかりません'
        exit
      end
      
      puts 'found'
      puts \"ID: #{actor.id}, ユーザー名: #{actor.username}, 表示名: #{actor.display_name || '未設定'}\"
      
      # Delete all dependent records in the correct order
      puts 'OAuthトークンを削除中...'
      Doorkeeper::AccessToken.where(resource_owner_id: actor.id).delete_all
      Doorkeeper::AccessGrant.where(resource_owner_id: actor.id).delete_all
      
      puts '会話参加情報を削除中...'
      actor.conversation_participants.delete_all
      
      puts 'ドメインブロックを削除中...'
      actor.domain_blocks.delete_all
      
      puts 'ブロック・ミュート関係を削除中...'
      actor.blocks.delete_all
      actor.mutes.delete_all
      actor.blocked_by.delete_all
      actor.muted_by.delete_all
      
      puts 'メンション情報を削除中...'
      actor.mentions.delete_all
      
      puts 'オブジェクトタグを削除中...'
      ObjectTag.joins(:object).where(objects: { actor_id: actor.id }).delete_all
      
      puts 'お気に入り・リブログを削除中...'
      actor.favourites.delete_all
      actor.reblogs.delete_all
      Favourite.joins(:object).where(objects: { actor_id: actor.id }).delete_all
      Reblog.joins(:object).where(objects: { actor_id: actor.id }).delete_all
      
      puts 'メディア添付ファイルを削除中...'
      actor.media_attachments.delete_all
      
      puts 'フォロー関係を削除中...'
      actor.following_relationships.delete_all
      actor.follower_relationships.delete_all
      actor.follows.delete_all
      actor.reverse_follows.delete_all
      
      puts '投稿を削除中...'
      actor.objects.delete_all
      
      puts 'アクティビティを削除中...'
      actor.activities.delete_all
      
      puts 'アカウントレコードを削除中...'
      actor.delete
      
      puts 'success'
      puts 'アカウントとすべての関連レコードが正常に削除されました'
      
    rescue => e
      puts 'error'
      puts e.message
      puts e.backtrace.first(3).join(\"\\n\")
    end
    ")
    
    echo "$deletion_result"
}

# Main function
main() {
    print_header "アカウント削除"
    
    if [[ -z "$1" ]]; then
        print_error "使用法: $0 <ユーザー名またはID>"
        echo "例: $0 tester"
        echo "例: $0 4"
        exit 1
    fi
    
    local identifier="$1"
    
    print_info "アカウントを削除しています: $identifier"
    echo ""
    
    # Perform deletion
    result=$(delete_actor "$identifier")
    
    # Parse result
    status=$(echo "$result" | head -1)
    
    case "$status" in
        "not_found")
            detail=$(echo "$result" | sed -n '2p')
            print_error "$detail"
            echo ""
            print_info "既存のローカルユーザー一覧:"
            local_users=$(run_with_env "
            actors = Actor.where(local: true)
            if actors.any?
              actors.each { |a| puts \"  - ID: #{a.id}, ユーザー名: #{a.username} (#{a.display_name || '表示名未設定'})\" }
            else
              puts '  ローカルユーザーがありません。'
            end
            ")
            echo "$local_users"
            exit 1
            ;;
        "found")
            actor_info=$(echo "$result" | sed -n '2p')
            print_info "対象アカウント: $actor_info"
            echo ""
            
            # Check if deletion was successful
            if echo "$result" | grep -q "success"; then
                print_success "アカウントが正常に削除されました！"
                echo ""
                print_info "削除ステップ完了:"
                echo "$result" | grep -E "を削除中|が正常に削除されました" | sed 's/^/  - /'
                echo ""
                
                # Show remaining account count
                remaining_count=$(run_with_env "puts Actor.where(local: true).count")
                print_info "残りのローカルアカウント数: $remaining_count"
            else
                detail=$(echo "$result" | tail -1)
                print_error "削除に失敗しました: $detail"
                exit 1
            fi
            ;;
        "error")
            detail=$(echo "$result" | sed -n '2,$p')
            print_error "削除中にエラーが発生しました:"
            echo "$detail"
            exit 1
            ;;
        *)
            print_error "予期しない結果:"
            echo "$result"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"