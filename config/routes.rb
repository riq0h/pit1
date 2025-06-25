Rails.application.routes.draw do
  # Health check endpoint
  get 'up' => 'rails/health#show', :as => :rails_health_check

  # PWA files
  get 'service-worker' => 'rails/pwa#service_worker', :as => :pwa_service_worker
  get 'manifest' => 'rails/pwa#manifest', :as => :pwa_manifest

  # ================================
  # ActivityPub & Federation Routes
  # ================================

  # ActivityPub Inbox
  post '/users/:username/inbox', to: 'inbox#create', as: :user_inbox

  # ActivityPub Outbox
  get '/users/:username/outbox', to: 'outbox#show', as: :user_outbox
  post '/users/:username/outbox', to: 'outbox#create'

  # ActivityPub Actor Profile  
  get '/users/:username', to: 'actors#show', as: :user_actor

  # WebFinger discovery
  get '/.well-known/webfinger', to: 'well_known#webfinger'
  get '/.well-known/host-meta', to: 'well_known#host_meta'
  get '/.well-known/nodeinfo', to: 'well_known#nodeinfo'

  # NodeInfo (https://nodeinfo.diaspora.software/)
  get '/nodeinfo/2.1', to: 'nodeinfo#show'

  # ActivityPub Activity endpoints
  get '/users/:username/inbox', to: 'inboxes#show'
  post '/users/:username/inbox', to: 'inboxes#create'
  get '/users/:username/outbox', to: 'outboxes#show'
  get '/users/:username/followers', to: 'followers#show'
  get '/users/:username/following', to: 'following#show'
  get '/users/:username/collections/featured', to: 'featured#show'

  # ActivityPub Object endpoints
  # ap_id の末尾部分 (nanoid) を使用
  get '/objects/:id', to: 'objects#show'
  get '/activities/:id', to: 'activities#show'

  # Shared inbox
  post '/inbox', to: 'shared_inboxes#create'

  # ================================
  # Frontend Routes (HTML)
  # ================================

  # ホームページ
  root 'home#index'

  # ユーザプロフィール
  get '/@:username', to: 'profiles#show', as: :profile
  # 個別投稿表示 (ap_id の末尾部分を使用)
  get '/@:username/:id', to: 'posts#show_html', as: :post_html

  # API形式URLからフロントエンド形式URLへのリダイレクト
  get '/users/:username/posts/:id', to: 'posts#redirect_to_frontend', as: :post_redirect

  # 認証・管理
  get '/login', to: 'sessions#new'
  post '/login', to: 'sessions#create'
  delete '/logout', to: 'sessions#destroy', as: :logout
  get '/config', to: 'config#show', as: :config
  patch '/config', to: 'config#update'
  
  # カスタム絵文字管理
  get '/config/custom_emojis', to: 'config#custom_emojis', as: :config_custom_emojis
  get '/config/custom_emojis/new', to: 'config#new_custom_emoji', as: :new_config_custom_emoji
  post '/config/custom_emojis', to: 'config#create_custom_emoji'
  get '/config/custom_emojis/:id/edit', to: 'config#edit_custom_emoji', as: :edit_config_custom_emoji
  patch '/config/custom_emojis/:id', to: 'config#update_custom_emoji', as: :config_custom_emoji
  delete '/config/custom_emojis/:id', to: 'config#destroy_custom_emoji'
  patch '/config/custom_emojis/:id/enable', to: 'config#enable_custom_emoji', as: :enable_config_custom_emoji
  patch '/config/custom_emojis/:id/disable', to: 'config#disable_custom_emoji', as: :disable_config_custom_emoji
  post '/config/custom_emojis/bulk_action', to: 'config#bulk_action_custom_emojis', as: :bulk_action_config_custom_emojis
  post '/config/custom_emojis/copy_remote', to: 'config#copy_remote_emojis', as: :copy_remote_config_custom_emojis
  post '/config/custom_emojis/discover_remote', to: 'config#discover_remote_emojis', as: :discover_remote_config_custom_emojis
  
  # Relay management routes
  get '/config/relays', to: 'config#relays', as: :config_relays
  post '/config/relays', to: 'config#create_relay'
  patch '/config/relays/:id', to: 'config#update_relay', as: :config_relay
  delete '/config/relays/:id', to: 'config#destroy_relay'

  # ================================
  # Mastodon API (サードパーティクライアント用)
  # ================================

  namespace :api do
    namespace :v1 do
      # OAuth & Apps
      post '/apps', to: 'apps#create'
      get '/apps/verify_credentials', to: 'apps#verify_credentials'

      # Accounts
      get '/accounts/verify_credentials', to: 'accounts#verify_credentials'
      patch '/accounts/update_credentials', to: 'accounts#update_credentials'
      get '/accounts/relationships', to: 'accounts#relationships'
      get '/accounts/search', to: 'accounts#search'
      get '/accounts/lookup', to: 'accounts#lookup'
      get '/accounts/:id', to: 'accounts#show'
      get '/accounts/:id/statuses', to: 'accounts#statuses'
      get '/accounts/:id/followers', to: 'accounts#followers'
      get '/accounts/:id/following', to: 'accounts#following'
      get '/accounts/:id/featured_tags', to: 'accounts#featured_tags'
      post '/accounts/:id/follow', to: 'accounts#follow'
      post '/accounts/:id/unfollow', to: 'accounts#unfollow'
      post '/accounts/:id/block', to: 'accounts#block'
      post '/accounts/:id/unblock', to: 'accounts#unblock'
      post '/accounts/:id/mute', to: 'accounts#mute'
      post '/accounts/:id/unmute', to: 'accounts#unmute'
      post '/accounts/:id/note', to: 'accounts#note'

      # Statuses
      get '/statuses/:id', to: 'statuses#show'
      get '/statuses/:id/context', to: 'statuses#context'
      get '/statuses/:id/history', to: 'statuses#history'
      get '/statuses/:id/source', to: 'statuses#source'
      post '/statuses', to: 'statuses#create'
      delete '/statuses/:id', to: 'statuses#destroy'
      put '/statuses/:id', to: 'statuses#update'
      post '/statuses/:id/favourite', to: 'statuses#favourite'
      post '/statuses/:id/unfavourite', to: 'statuses#unfavourite'
      post '/statuses/:id/reblog', to: 'statuses#reblog'
      post '/statuses/:id/unreblog', to: 'statuses#unreblog'
      post '/statuses/:id/quote', to: 'statuses#quote'
      get '/statuses/:id/quoted_by', to: 'statuses#quoted_by'
      get '/statuses/:id/reblogged_by', to: 'statuses#reblogged_by'
      get '/statuses/:id/favourited_by', to: 'statuses#favourited_by'
      post '/statuses/:id/pin', to: 'statuses#pin'
      post '/statuses/:id/unpin', to: 'statuses#unpin'
      post '/statuses/:id/bookmark', to: 'statuses#bookmark'
      post '/statuses/:id/unbookmark', to: 'statuses#unbookmark'

      # Tags
      get '/tags/:id', to: 'tags#show'
      post '/tags/:id/follow', to: 'tags#follow'
      post '/tags/:id/unfollow', to: 'tags#unfollow'
      
      # Timelines
      get '/timelines/home', to: 'timelines#home'
      get '/timelines/public', to: 'timelines#public'
      get '/timelines/tag/:hashtag', to: 'timelines#tag'

      # Instance
      get '/instance', to: 'instance#show'

      # Media
      post '/media', to: 'media#create'
      get '/media/:id', to: 'media#show'
      put '/media/:id', to: 'media#update'

      # Conversations (Direct Messages)
      get '/conversations', to: 'conversations#index'
      get '/conversations/:id', to: 'conversations#show'
      delete '/conversations/:id', to: 'conversations#destroy'
      post '/conversations/:id/read', to: 'conversations#read'

      # Notifications
      get '/notifications', to: 'notifications#index'
      get '/notifications/:id', to: 'notifications#show'
      post '/notifications/clear', to: 'notifications#clear'
      post '/notifications/:id/dismiss', to: 'notifications#dismiss'

      # Streaming (WebSocket)
      get '/streaming', to: 'streaming#index'
      
      # Server-Sent Events
      namespace :streaming do
        get '/stream', to: 'sse#stream'
      end

      # Domain blocks
      get '/domain_blocks', to: 'domain_blocks#index'
      post '/domain_blocks', to: 'domain_blocks#create'
      delete '/domain_blocks', to: 'domain_blocks#destroy'

      # Custom emojis
      get '/custom_emojis', to: 'custom_emojis#index'

      # Bookmarks
      get '/bookmarks', to: 'bookmarks#index'

      # Favourites
      get '/favourites', to: 'favourites#index'

      # Follow requests
      get '/follow_requests', to: 'follow_requests#index'
      post '/follow_requests/:id/authorize', to: 'follow_requests#authorize'
      post '/follow_requests/:id/reject', to: 'follow_requests#reject'
      
      # Markers
      get '/markers', to: 'markers#index'
      post '/markers', to: 'markers#create'
      
      # Lists
      get '/lists', to: 'lists#index'
      post '/lists', to: 'lists#create'
      get '/lists/:id', to: 'lists#show'
      put '/lists/:id', to: 'lists#update'
      delete '/lists/:id', to: 'lists#destroy'
      get '/lists/:id/accounts', to: 'lists#accounts'
      post '/lists/:id/accounts', to: 'lists#add_accounts'
      delete '/lists/:id/accounts', to: 'lists#remove_accounts'
      
      # Featured tags
      get '/featured_tags', to: 'featured_tags#index'
      post '/featured_tags', to: 'featured_tags#create'
      delete '/featured_tags/:id', to: 'featured_tags#destroy'
      get '/featured_tags/suggestions', to: 'featured_tags#suggestions'

      # Followed tags
      get '/followed_tags', to: 'followed_tags#index'
      
      # Polls
      get '/polls/:id', to: 'polls#show'
      post '/polls/:id/votes', to: 'polls#vote'
      
      # Scheduled statuses
      get '/scheduled_statuses', to: 'scheduled_statuses#index'
      get '/scheduled_statuses/:id', to: 'scheduled_statuses#show'
      put '/scheduled_statuses/:id', to: 'scheduled_statuses#update'
      delete '/scheduled_statuses/:id', to: 'scheduled_statuses#destroy'
      
      # Endorsements (stub)
      get '/endorsements', to: 'endorsements#index'
      post '/accounts/:id/pin', to: 'endorsements#create'
      delete '/accounts/:id/unpin', to: 'endorsements#destroy'
      
      # Reports (stub)
      post '/reports', to: 'reports#create'
      
      # Suggestions
      get '/suggestions', to: 'suggestions#index'
      delete '/suggestions/:id', to: 'suggestions#destroy'
      
      # Trends
      get '/trends', to: 'trends#index'
      get '/trends/tags', to: 'trends#tags'
      get '/trends/statuses', to: 'trends#statuses'
      get '/trends/links', to: 'trends#links'
      
      # Filters
      get '/filters', to: 'filters#index'
      post '/filters', to: 'filters#create'
      get '/filters/:id', to: 'filters#show'
      put '/filters/:id', to: 'filters#update'
      delete '/filters/:id', to: 'filters#destroy'
      
      # Preferences
      get '/preferences', to: 'preferences#show'
      
      # Announcements
      get '/announcements', to: 'announcements#index'
      post '/announcements/:id/dismiss', to: 'announcements#dismiss'
      
      # Push subscriptions
      namespace :push do
        get '/subscription', to: 'subscription#show'
        post '/subscription', to: 'subscription#create'
        put '/subscription', to: 'subscription#update'
        delete '/subscription', to: 'subscription#destroy'
      end

      # Admin APIs
      namespace :admin do
        get '/dashboard', to: 'dashboard#show'
        
        resources :accounts, only: [:index, :show, :destroy] do
          member do
            post :enable
            post :suspend
          end
        end
        
        resources :reports, only: [:index, :show] do
          member do
            post :assign_to_self
            post :unassign
            post :resolve
            post :reopen
          end
        end
      end
    end

    namespace :v2 do
      # 検索機能
      get '/search', to: 'search#index'
      
      # Instance (v2)
      get '/instance', to: 'instance#show'
      
      # Suggestions (v2)
      get '/suggestions', to: 'suggestions#index'
      
      # Trends (v2)
      get '/trends/tags', to: 'trends#tags'
      get '/trends/statuses', to: 'trends#statuses'
      get '/trends/links', to: 'trends#links'
      
      # Filters (v2)
      get '/filters', to: 'filters#index'
      post '/filters', to: 'filters#create'
      get '/filters/:id', to: 'filters#show'
      put '/filters/:id', to: 'filters#update'
      delete '/filters/:id', to: 'filters#destroy'
      
      # Media (v2)
      post '/media', to: 'media#create'
    end
  end

  # ================================
  # Action Cable (WebSocket)
  # ================================
  mount ActionCable.server => '/cable'

  # ================================
  # OAuth 2.0 Routes
  # ================================
  
  use_doorkeeper

  # ================================
  # Admin Routes
  # ================================

  namespace :admin do
    get '/', to: 'dashboard#index'

    # Users (2ユーザ制限管理)
    get '/users', to: 'users#index'
    get '/users/:id', to: 'users#show'

    # Federation
    get '/instances', to: 'instances#index'
    post '/instances/:domain/block', to: 'instances#block'
    delete '/instances/:domain/block', to: 'instances#unblock'

    # Reports
    get '/reports', to: 'reports#index'
    get '/reports/:id', to: 'reports#show'
  end

  # ================================
  # Media & Assets
  # ================================

  # メディアファイル配信
  get '/media/:id', to: 'media#show', as: :media_file
  get '/media/:id/thumb', to: 'media#thumbnail', as: :media_thumbnail

  # ================================
  # Additional Routes
  # ================================

  # RSS/Atom feeds
  get '/@:username.rss', to: 'feeds#user', format: :rss
  get '/local.atom', to: 'feeds#local', format: :atom

  # Static pages
  get '/about', to: 'pages#about'
  get '/terms', to: 'pages#terms'
  get '/privacy', to: 'pages#privacy'

  # Search
  get '/search/index', to: 'search#index', as: :search_index

  # Error pages
  get '/404', to: 'errors#not_found'
  get '/500', to: 'errors#internal_server_error'
  
  # Catch-all route for 404 errors (must be last, but exclude Active Storage paths)
  match '*path', to: 'errors#not_found', via: :all, constraints: ->(req) { 
    !req.path.start_with?('/rails/active_storage') 
  }
end
