Rails.application.routes.draw do
  # OAuth 2.0 endpoints (Doorkeeper)
  scope :oauth do
    get '/authorize' => 'oauth/authorizations#new', as: :oauth_authorization
    post '/authorize' => 'oauth/authorizations#create'
    delete '/authorize' => 'oauth/authorizations#destroy'
    post '/token' => 'oauth/tokens#create', as: :oauth_token
    post '/revoke' => 'oauth/tokens#revoke', as: :oauth_revoke
  end
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

  # 認証・管理
  get '/login', to: 'sessions#new'
  post '/login', to: 'sessions#create'
  delete '/logout', to: 'sessions#destroy', as: :logout
  get '/config', to: 'config#show', as: :config
  patch '/config', to: 'config#update'

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
      get '/accounts/:id', to: 'accounts#show'
      get '/accounts/:id/statuses', to: 'accounts#statuses'
      get '/accounts/:id/followers', to: 'accounts#followers'
      get '/accounts/:id/following', to: 'accounts#following'
      post '/accounts/:id/follow', to: 'accounts#follow'
      post '/accounts/:id/unfollow', to: 'accounts#unfollow'
      post '/accounts/:id/block', to: 'accounts#block'
      post '/accounts/:id/unblock', to: 'accounts#unblock'
      post '/accounts/:id/mute', to: 'accounts#mute'
      post '/accounts/:id/unmute', to: 'accounts#unmute'

      # Statuses
      get '/statuses/:id', to: 'statuses#show'
      post '/statuses', to: 'statuses#create'
      delete '/statuses/:id', to: 'statuses#destroy'
      put '/statuses/:id', to: 'statuses#update'
      post '/statuses/:id/favourite', to: 'statuses#favourite'
      post '/statuses/:id/unfavourite', to: 'statuses#unfavourite'
      post '/statuses/:id/reblog', to: 'statuses#reblog'
      post '/statuses/:id/unreblog', to: 'statuses#unreblog'

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

      # Streaming (WebSocket)
      get '/streaming', to: 'streaming#index'

      # Search
      get '/search', to: 'search#index'

      # Domain blocks
      get '/domain_blocks', to: 'domain_blocks#index'
      post '/domain_blocks', to: 'domain_blocks#create'
      delete '/domain_blocks', to: 'domain_blocks#destroy'
    end
  end

  # ================================
  # OAuth 2.0 Routes
  # ================================

  namespace :oauth do
    get '/authorize', to: 'authorizations#new'
    post '/authorize', to: 'authorizations#create'
    post '/token', to: 'tokens#create'
    post '/revoke', to: 'tokens#revoke'
  end

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
  
  # Catch-all route for 404 errors (must be last)
  match '*path', to: 'errors#not_found', via: :all
end
