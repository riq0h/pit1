class CreateObjects < ActiveRecord::Migration[8.0]
  def change
    create_table :objects do |t|
      # ActivityPub識別
      t.string :ap_id, null: false, index: { unique: true }
      t.string :object_type, null: false

      # 関連情報
      t.references :actor, null: false, foreign_key: true
      t.string :in_reply_to_ap_id
      t.string :conversation_ap_id

      # 内容
      t.text :content
      t.text :content_plaintext
      t.string :summary
      t.string :url
      t.string :language, default: 'ja'

      # メディア情報
      t.string :media_type
      t.string :blurhash
      t.integer :width
      t.integer :height

      # 設定
      t.boolean :sensitive, default: false
      t.string :visibility, default: 'public'

      # ActivityPub データ
      t.json :raw_data
      t.datetime :published_at

      # メタデータ
      t.boolean :local, default: false
      t.integer :replies_count, default: 0
      t.integer :reblogs_count, default: 0
      t.integer :favourites_count, default: 0

      t.timestamps
    end

    # インデックス設定
    add_index :objects, :ap_id, unique: true unless index_exists?(:objects, :ap_id)
    add_index :objects, :object_type unless index_exists?(:objects, :object_type)
    add_index :objects, %i[actor_id published_at] unless index_exists?(:objects, %i[actor_id published_at])
    add_index :objects, :in_reply_to_ap_id unless index_exists?(:objects, :in_reply_to_ap_id)
    add_index :objects, :conversation_ap_id unless index_exists?(:objects, :conversation_ap_id)
    add_index :objects, :local unless index_exists?(:objects, :local)
    add_index :objects, :visibility unless index_exists?(:objects, :visibility)
    add_index :objects, :published_at unless index_exists?(:objects, :published_at)

    # 全文検索インデックス
    execute <<-SQL
      CREATE VIRTUAL TABLE objects_fts USING fts5(
        content_plaintext,
        summary,
        content='objects',
        content_rowid='id'
      );

      CREATE TRIGGER objects_fts_insert AFTER INSERT ON objects BEGIN
        INSERT INTO objects_fts(rowid, content_plaintext, summary)
        VALUES (new.id, new.content_plaintext, new.summary);
      END;

      CREATE TRIGGER objects_fts_delete AFTER DELETE ON objects BEGIN
        INSERT INTO objects_fts(objects_fts, rowid, content_plaintext, summary)
        VALUES('delete', old.id, old.content_plaintext, old.summary);
      END;

      CREATE TRIGGER objects_fts_update AFTER UPDATE ON objects BEGIN
        INSERT INTO objects_fts(objects_fts, rowid, content_plaintext, summary)
        VALUES('delete', old.id, old.content_plaintext, old.summary);
        INSERT INTO objects_fts(rowid, content_plaintext, summary)
        VALUES (new.id, new.content_plaintext, new.summary);
      END;
    SQL
  end

  def down
    execute 'DROP TRIGGER IF EXISTS objects_fts_update'
    execute 'DROP TRIGGER IF EXISTS objects_fts_delete'
    execute 'DROP TRIGGER IF EXISTS objects_fts_insert'
    execute 'DROP TABLE IF EXISTS objects_fts'
    drop_table :objects
  end
end
