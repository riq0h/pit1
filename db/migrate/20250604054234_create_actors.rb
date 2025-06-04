class CreateActors < ActiveRecord::Migration[8.0]
  def change
    create_table :actors do |t|
      # 基本識別情報
      t.string :username, null: false
      t.string :domain, null: true
      t.string :ap_id, null: false

      # プロフィール情報
      t.string :display_name
      t.text :summary
      t.string :avatar_url
      t.string :header_url

      # ActivityPub エンドポイント
      t.string :inbox_url, null: false
      t.string :outbox_url, null: false
      t.string :followers_url
      t.string :following_url
      t.string :shared_inbox_url

      # 暗号化情報
      t.text :public_key, null: false
      t.text :private_key

      # 統計情報
      t.integer :followers_count, default: 0
      t.integer :following_count, default: 0
      t.integer :posts_count, default: 0

      # メタデータ
      t.boolean :local, default: false, null: false
      t.boolean :suspended, default: false
      t.boolean :locked, default: false
      t.datetime :last_fetched_at

      t.timestamps
    end

    # インデックス設定
    add_index :actors, %i[username domain], unique: true unless index_exists?(:actors, %i[username domain])
    add_index :actors, :domain unless index_exists?(:actors, :domain)
    add_index :actors, :local unless index_exists?(:actors, :local)
    add_index :actors, :ap_id, unique: true unless index_exists?(:actors, :ap_id)
    add_index :actors, :inbox_url unless index_exists?(:actors, :inbox_url)
    add_index :actors, :shared_inbox_url unless index_exists?(:actors, :shared_inbox_url)

    # 2ユーザー制限トリガー
    execute <<-SQL
      CREATE TRIGGER limit_local_actors
      BEFORE INSERT ON actors
      WHEN NEW.local = 1
      BEGIN
        SELECT CASE
          WHEN (SELECT COUNT(*) FROM actors WHERE local = 1) >= 2
          THEN RAISE(ABORT, 'This spaceship is a two-seater.')
        END;
      END;
    SQL
  end

  def down
    execute 'DROP TRIGGER IF EXISTS limit_local_actors'
    drop_table :actors
  end
end
