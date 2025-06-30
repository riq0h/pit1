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
      database: database_path.to_s,
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
        
        cable_schema_path = Rails.root.join('db/cable_schema.rb')
        if File.exist?(cable_schema_path)
          load cable_schema_path
          Rails.logger.info "✅ Solid Cable database initialized from schema"
        else
          # スキーマファイルがない場合は手動でテーブル作成
          ActiveRecord::Base.connection.execute(<<~SQL)
            CREATE TABLE IF NOT EXISTS solid_cable_messages (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              channel VARCHAR NOT NULL,
              payload TEXT NOT NULL,
              created_at DATETIME NOT NULL
            )
          SQL
          ActiveRecord::Base.connection.execute(<<~SQL)
            CREATE INDEX IF NOT EXISTS index_solid_cable_messages_on_channel 
            ON solid_cable_messages (channel)
          SQL
          ActiveRecord::Base.connection.execute(<<~SQL)
            CREATE INDEX IF NOT EXISTS index_solid_cable_messages_on_created_at 
            ON solid_cable_messages (created_at)
          SQL
          Rails.logger.info "✅ Solid Cable database initialized manually"
        end
      end
      
    rescue ActiveRecord::NoDatabaseError
      # データベースファイルが存在しない場合は作成
      Rails.logger.info "📁 Creating cable database file"
      ActiveRecord::Tasks::DatabaseTasks.create(ActiveRecord::Base.configurations.configs_for(env_name: Rails.env, name: 'cable').first)
      
      # テーブル作成
      ActiveRecord::Base.establish_connection(:cable)
      
      cable_schema_path = Rails.root.join('db/cable_schema.rb')
      if File.exist?(cable_schema_path)
        load cable_schema_path
        Rails.logger.info "✅ Solid Cable database created and initialized from schema"
      else
        # スキーマファイルがない場合は手動でテーブル作成
        ActiveRecord::Base.connection.execute(<<~SQL)
          CREATE TABLE IF NOT EXISTS solid_cable_messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            channel VARCHAR NOT NULL,
            payload TEXT NOT NULL,
            created_at DATETIME NOT NULL
          )
        SQL
        ActiveRecord::Base.connection.execute(<<~SQL)
          CREATE INDEX IF NOT EXISTS index_solid_cable_messages_on_channel 
          ON solid_cable_messages (channel)
        SQL
        ActiveRecord::Base.connection.execute(<<~SQL)
          CREATE INDEX IF NOT EXISTS index_solid_cable_messages_on_created_at 
          ON solid_cable_messages (created_at)
        SQL
        Rails.logger.info "✅ Solid Cable database created and initialized manually"
      end
      
    rescue => e
      Rails.logger.warn "⚠️  Solid Cable setup failed: #{e.message}"
      
    ensure
      # メインデータベースに接続を戻す
      ActiveRecord::Base.establish_connection(:primary)
    end
  end
end