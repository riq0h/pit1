class CreateActors < ActiveRecord::Migration[8.0]
  def change
    create_table :actors, id: :string do |t|
      # 基本情報
      t.string :username, null: false, limit: 20
      t.string :domain, limit: 255
      t.string :display_name, limit: 100
      t.text :summary

      # ActivityPub情報
      t.string :ap_id, null: false
      t.string :inbox_url, null: false
      t.string :outbox_url, null: false
      t.string :followers_url, null: false
      t.string :following_url, null: false

      # 鍵ペア
      t.text :public_key, null: false
      t.text :private_key # ローカルユーザーのみ

      # メディア
      t.string :avatar_url
      t.string :header_url

      # 設定
      t.boolean :local, null: false, default: false
      t.boolean :locked, null: false, default: false
      t.boolean :bot, null: false, default: false
      t.boolean :suspended, null: false, default: false

      # pit1特有: ローカルアカウントのスロット番号（1 or 2）
      t.integer :local_account_slot, limit: 1

      # 統計
      t.integer :followers_count, null: false, default: 0
      t.integer :following_count, null: false, default: 0
      t.integer :posts_count, null: false, default: 0

      # ActivityPub メタデータ
      t.json :raw_data
      t.datetime :last_fetched_at

      t.timestamps
    end

    # インデックス
    add_index :actors, :ap_id, unique: true
    add_index :actors, %i[username domain], unique: true
    add_index :actors, :domain
    add_index :actors, :local
    add_index :actors, :suspended
    add_index :actors, %i[local local_account_slot], unique: true, where: 'local = 1'

    # SQLiteトリガー: 2アカウント制限
    reversible do |dir|
      dir.up do
        execute <<-SQL
          CREATE TRIGGER limit_local_actors
          BEFORE INSERT ON actors
          WHEN NEW.local = 1
          BEGIN
            -- 空いているスロット番号を自動割り当て
            UPDATE NEW SET local_account_slot = (
              CASE#{' '}
                WHEN NOT EXISTS (SELECT 1 FROM actors WHERE local = 1 AND local_account_slot = 1) THEN 1
                WHEN NOT EXISTS (SELECT 1 FROM actors WHERE local = 1 AND local_account_slot = 2) THEN 2
                ELSE RAISE(ABORT, 'This spaceship is a two-seater. Maximum 2 local accounts allowed.')
              END
            );
          END;
        SQL
      end

      dir.down do
        execute 'DROP TRIGGER IF EXISTS limit_local_actors;'
      end
    end
  end
end
