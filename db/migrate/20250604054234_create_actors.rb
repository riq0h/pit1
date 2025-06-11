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

  end
end
