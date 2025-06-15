#!/bin/bash

# Letter ActivityPub Instance - Account Management Script
# Manages local accounts with 2-account limit enforcement

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

# Function to get current local accounts
get_local_accounts() {
    run_with_env "
    accounts = Actor.where(local: true)
    accounts.each_with_index do |account, index|
      puts \"#{index + 1}. #{account.username} (#{account.display_name || 'No display name'})\"
    end
    puts accounts.count
    " | tail -1
}

# Function to list account details
list_accounts_detailed() {
    echo ""
    print_info "現在のローカルアカウント:"
    echo ""
    
    run_with_env "
    accounts = Actor.where(local: true)
    if accounts.any?
      accounts.each_with_index do |account, index|
        puts \"#{index + 1}. ユーザー名: #{account.username}\"
        puts \"   表示名: #{account.display_name || '未設定'}\"
        puts \"   作成日: #{account.created_at.strftime('%Y-%m-%d %H:%M')}\"
        puts \"   投稿数: #{account.posts_count || 0}\"
        puts \"   フォロー数: #{account.following_count || 0}\"
        puts \"   フォロワー数: #{account.followers_count || 0}\"
        puts \"\"
      end
    else
      puts \"ローカルアカウントはありません\"
    fi
    "
}

# Function to create new account
create_account() {
    echo ""
    print_header "新しいアカウントの作成"
    echo ""
    
    print_info "アカウント情報を入力してください:"
    echo ""
    
    # Get username
    while true; do
        read -p "ユーザー名 (英数字とアンダースコアのみ): " username
        
        if [[ -z "$username" ]]; then
            print_error "ユーザー名は必須です"
            continue
        fi
        
        if [[ ! "$username" =~ ^[a-zA-Z0-9_]+$ ]]; then
            print_error "ユーザー名は英数字とアンダースコアのみ使用できます"
            continue
        fi
        
        # Check if username already exists
        existing_check=$(run_with_env "
        if Actor.exists?(username: '$username', local: true)
          puts 'exists'
        else
          puts 'available'
        fi
        ")
        
        if [[ "$existing_check" == "exists" ]]; then
            print_error "ユーザー名 '$username' は既に存在します"
            continue
        fi
        
        break
    done
    
    # Get password
    while true; do
        read -s -p "パスワード (6文字以上): " password
        echo ""
        if [[ ${#password} -lt 6 ]]; then
            print_error "パスワードは6文字以上である必要があります"
            continue
        fi
        
        read -s -p "パスワードを再入力: " password_confirm
        echo ""
        if [[ "$password" != "$password_confirm" ]]; then
            print_error "パスワードが一致しません"
            continue
        fi
        
        break
    done
    
    # Get display name (optional)
    read -p "表示名 (オプション): " display_name
    
    # Get summary (optional)
    read -p "プロフィール (オプション): " summary
    
    echo ""
    print_info "入力内容を確認してください:"
    echo "  ユーザー名: $username"
    echo "  表示名: ${display_name:-'未設定'}"
    echo "  プロフィール: ${summary:-'未設定'}"
    echo ""
    
    read -p "この内容でアカウントを作成しますか? (y/N): " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "アカウント作成をキャンセルしました"
        return 1
    fi
    
    echo ""
    print_info "アカウントを作成中..."
    
    # Create account using Rails
    creation_result=$(run_with_env "
    begin
      actor = Actor.new(
        username: '$username',
        password: '$password',
        display_name: '$display_name',
        summary: '$summary',
        local: true,
        discoverable: true,
        manually_approves_followers: false
      )
      
      if actor.save
        puts 'success'
        puts actor.id
      else
        puts 'error'
        puts actor.errors.full_messages.join(', ')
      end
    rescue => e
      puts 'exception'
      puts e.message
    end
    ")
    
    result_status=$(echo "$creation_result" | head -1)
    result_detail=$(echo "$creation_result" | tail -1)
    
    if [[ "$result_status" == "success" ]]; then
        print_success "アカウントが正常に作成されました!"
        echo ""
        print_info "アカウント詳細:"
        echo "  ユーザー名: $username"
        echo "  表示名: ${display_name:-'未設定'}"
        echo "  ActivityPub ID: $ACTIVITYPUB_PROTOCOL://$ACTIVITYPUB_DOMAIN/users/$username"
        echo "  WebFinger: @$username@$ACTIVITYPUB_DOMAIN"
        echo ""
        print_info "次のステップ:"
        echo "  1. OAuthトークンを生成: ./scripts/create_oauth_token.sh"
        echo "  2. アバターを設定: Mastodon API /api/v1/accounts/update_credentials"
        echo "  3. テスト投稿を作成: ./scripts/create_test_posts.sh"
        
        return 0
    else
        print_error "アカウント作成に失敗しました: $result_detail"
        return 1
    fi
}

# Function to delete account
delete_account() {
    local account_number=$1
    
    print_info "アカウント削除の確認..."
    
    # Get account details
    account_info=$(run_with_env "
    accounts = Actor.where(local: true).order(:created_at)
    if accounts.length >= $account_number
      account = accounts[$((account_number - 1))]
      puts account.username
      puts account.display_name || 'なし'
      puts account.posts_count || 0
      puts account.following_count || 0
      puts account.followers_count || 0
      puts account.id
    else
      puts 'invalid'
    end
    ")
    
    if [[ "$(echo "$account_info" | head -1)" == "invalid" ]]; then
        print_error "無効なアカウント番号です"
        return 1
    fi
    
    username=$(echo "$account_info" | sed -n '1p')
    display_name=$(echo "$account_info" | sed -n '2p')
    posts_count=$(echo "$account_info" | sed -n '3p')
    following_count=$(echo "$account_info" | sed -n '4p')
    followers_count=$(echo "$account_info" | sed -n '5p')
    account_id=$(echo "$account_info" | sed -n '6p')
    
    echo ""
    print_warning "削除対象のアカウント:"
    echo "  ユーザー名: $username"
    echo "  表示名: $display_name"
    echo "  投稿数: $posts_count"
    echo "  フォロー数: $following_count"
    echo "  フォロワー数: $followers_count"
    echo ""
    print_error "この操作は取り消すことができません!"
    echo ""
    
    read -p "本当にこのアカウントを削除しますか? 'DELETE' と入力してください: " confirm
    
    if [[ "$confirm" != "DELETE" ]]; then
        print_warning "アカウント削除をキャンセルしました"
        return 1
    fi
    
    echo ""
    print_info "アカウントを削除中..."
    
    # Delete account
    deletion_result=$(run_with_env "
    begin
      actor = Actor.find($account_id)
      actor.destroy!
      puts 'success'
    rescue => e
      puts 'error'
      puts e.message
    end
    ")
    
    result_status=$(echo "$deletion_result" | head -1)
    
    if [[ "$result_status" == "success" ]]; then
        print_success "アカウント '$username' が正常に削除されました"
        return 0
    else
        result_detail=$(echo "$deletion_result" | tail -1)
        print_error "アカウント削除に失敗しました: $result_detail"
        return 1
    fi
}

# Main script
main() {
    print_header "Letter ActivityPub アカウント管理"
    
    print_info "このインスタンスは最大2個のローカルアカウントまで作成できます"
    echo ""
    
    # Get current account count
    account_count=$(get_local_accounts)
    
    case $account_count in
        0)
            print_info "現在のローカルアカウント数: 0/2"
            echo ""
            print_success "1個目のアカウントを作成します"
            create_account
            ;;
        1)
            print_info "現在のローカルアカウント数: 1/2"
            list_accounts_detailed
            echo ""
            print_success "2個目のアカウントを作成できます"
            echo ""
            read -p "新しいアカウントを作成しますか? (y/N): " -n 1 -r
            echo ""
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                create_account
            else
                print_info "操作をキャンセルしました"
            fi
            ;;
        2)
            print_warning "現在のローカルアカウント数: 2/2 (上限に達しています)"
            list_accounts_detailed
            echo ""
            print_info "新しいアカウントを作成するには、既存のアカウントを削除する必要があります"
            echo ""
            echo "選択してください:"
            echo "1) アカウント1を削除して新しいアカウントを作成"
            echo "2) アカウント2を削除して新しいアカウントを作成"  
            echo "3) キャンセル"
            echo ""
            read -p "選択 (1-3): " -n 1 -r choice
            echo ""
            echo ""
            
            case $choice in
                1)
                    if delete_account 1; then
                        echo ""
                        print_info "新しいアカウントを作成します"
                        create_account
                    fi
                    ;;
                2)
                    if delete_account 2; then
                        echo ""
                        print_info "新しいアカウントを作成します"
                        create_account
                    fi
                    ;;
                3)
                    print_info "操作をキャンセルしました"
                    ;;
                *)
                    print_error "無効な選択です"
                    exit 1
                    ;;
            esac
            ;;
        *)
            print_error "予期しないアカウント数です: $account_count"
            print_info "データベースの状態を確認してください"
            exit 1
            ;;
    esac
    
    echo ""
    print_header "アカウント管理完了"
}

# Run main function
main "$@"