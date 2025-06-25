# frozen_string_literal: true

# Solid Cable自動設定
if Rails.env.development? || Rails.env.production?
  # database.ymlにcable設定がない場合は動的に追加
  unless ActiveRecord::Base.configurations.configs_for(env_name: Rails.env, name: 'cable')
    Rails.logger.info "🔧 Adding cable database configuration dynamically"
    
    database_path = Rails.root.join("storage/cable_#{Rails.env}.sqlite3")
    
    config = ActiveRecord::DatabaseConfigurations::HashConfig.new(
      Rails.env,
      'cable',
      adapter: 'sqlite3',
      database: database_path,
      pool: ENV.fetch("RAILS_MAX_THREADS") { 20 }.to_i,
      timeout: 30000,
      pragma: {
        journal_mode: :wal,
        synchronous: :normal,
        cache_size: 10000,
        foreign_keys: :on,
        temp_store: :memory,
        mmap_size: 134217728
      }
    )
    
    ActiveRecord::Base.configurations.configurations << config
  end
  
  # アプリケーション初期化後にcableデータベースをセットアップ
  Rails.application.config.after_initialize do
    begin
      # cableデータベースに接続
      ActiveRecord::Base.establish_connection(:cable)
      
      # テーブルが存在しない場合のみ作成
      unless ActiveRecord::Base.connection.table_exists?('solid_cable_messages')
        Rails.logger.info "📡 Creating Solid Cable tables"
        load Rails.root.join('db/cable_schema.rb')
        Rails.logger.info "✅ Solid Cable database initialized"
      end
      
    rescue ActiveRecord::NoDatabaseError
      # データベースファイルが存在しない場合は作成
      Rails.logger.info "📁 Creating cable database file"
      ActiveRecord::Tasks::DatabaseTasks.create(ActiveRecord::Base.configurations.configs_for(env_name: Rails.env, name: 'cable').first)
      
      # テーブル作成
      ActiveRecord::Base.establish_connection(:cable)
      load Rails.root.join('db/cable_schema.rb')
      Rails.logger.info "✅ Solid Cable database created and initialized"
      
    rescue => e
      Rails.logger.warn "⚠️  Solid Cable setup failed: #{e.message}"
      
    ensure
      # メインデータベースに接続を戻す
      ActiveRecord::Base.establish_connection(:primary)
    end
  end
end