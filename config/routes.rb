Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Health check endpoint
  get 'up' => 'rails/health#show', :as => :rails_health_check

  # PWA files
  get 'service-worker' => 'rails/pwa#service_worker', :as => :pwa_service_worker
  get 'manifest' => 'rails/pwa#manifest', :as => :pwa_manifest

  # ActivityPub & Federation endpoints (placeholder)
  # These will be implemented in later tasks

  # WebFinger discovery
  get '/.well-known/webfinger', to: 'well_known#webfinger'
  get '/.well-known/host-meta', to: 'well_known#host_meta'
  get '/.well-known/nodeinfo', to: 'well_known#nodeinfo'

  # NodeInfo
  get '/nodeinfo/2.1', to: 'nodeinfo#show'

  # ActivityPub Actor endpoints
  get '/users/:username', to: 'actors#show', constraints: { format: 'json' }
  get '/users/:username/inbox', to: 'inboxes#show'
  post '/users/:username/inbox', to: 'inboxes#create'
  get '/users/:username/outbox', to: 'outboxes#show'
  get '/users/:username/followers', to: 'followers#show'
  get '/users/:username/following', to: 'following#show'

  # Individual posts
  get '/posts/:slug', to: 'posts#show'

  # Frontend routes
  root 'home#index'
  get '/@:username', to: 'profiles#show', as: :profile
  get '/@:username/:slug', to: 'posts#show_html', as: :post_html
  get '/login', to: 'sessions#new'
  post '/login', to: 'sessions#create'
  delete '/logout', to: 'sessions#destroy'
  get '/settings', to: 'admin/settings#show'

  # Mastodon API (placeholder - will be implemented later)
  namespace :api do
    namespace :v1 do
      # Will be implemented in later tasks
    end
  end

  # OAuth endpoints (placeholder)
  namespace :oauth do
    # Will be implemented in later tasks
  end
end
