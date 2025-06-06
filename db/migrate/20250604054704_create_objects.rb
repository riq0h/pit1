class CreateObjects < ActiveRecord::Migration[8.0]
  def change
    create_table :objects, id: :string do |t|
      # ActivityPub情報
      t.string :ap_id, null: false
      t.string :object_type, null: false, default: 'Note'
      t.references :actor, type: :string, null: false, foreign_key: true

      # コンテンツ（HTMLとプレーンテキストの両方を保持）
      t.text :content                    # HTML版
      t.text :content_plaintext          # プレーン版（FTS5検索用）

      t.text :summary                    # Content Warning
      t.string :url
      t.string :language, default: 'ja'

      # 返信・会話
      t.string :in_reply_to_ap_id
      t.string :conversation_ap_id

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

    # 基本インデックス
    add_index :objects, :ap_id, unique: true unless index_exists?(:objects, :ap_id)
    add_index :objects, :object_type unless index_exists?(:objects, :object_type)
    add_index :objects, :published_at unless index_exists?(:objects, :published_at)
    add_index :objects, :visibility unless index_exists?(:objects, :visibility)
    add_index :objects, :local unless index_exists?(:objects, :local)
    add_index :objects, :in_reply_to_ap_id unless index_exists?(:objects, :in_reply_to_ap_id)
    add_index :objects, :conversation_ap_id unless index_exists?(:objects, :conversation_ap_id)

    # FTS5仮想テーブル
    reversible do |dir|
      dir.up do
        execute <<-SQL
          CREATE VIRTUAL TABLE IF NOT EXISTS post_search USING fts5(
            content_plaintext,
            summary,
            content='objects',
            content_rowid='id'
          );
        SQL

        execute <<-SQL
          CREATE TRIGGER IF NOT EXISTS post_search_insert#{' '}
          AFTER INSERT ON objects#{' '}
          BEGIN
            INSERT INTO post_search(rowid, content_plaintext, summary)#{' '}
            VALUES (new.id, COALESCE(new.content_plaintext, ''), COALESCE(new.summary, ''));
          END;
        SQL

        execute <<-SQL
          CREATE TRIGGER IF NOT EXISTS post_search_delete#{' '}
          AFTER DELETE ON objects#{' '}
          BEGIN
            INSERT INTO post_search(post_search, rowid, content_plaintext, summary)#{' '}
            VALUES('delete', old.id, COALESCE(old.content_plaintext, ''), COALESCE(old.summary, ''));
          END;
        SQL

        execute <<-SQL
          CREATE TRIGGER IF NOT EXISTS post_search_update#{' '}
          AFTER UPDATE ON objects#{' '}
          BEGIN
            INSERT INTO post_search(post_search, rowid, content_plaintext, summary)#{' '}
            VALUES('delete', old.id, COALESCE(old.content_plaintext, ''), COALESCE(old.summary, ''));
            INSERT INTO post_search(rowid, content_plaintext, summary)#{' '}
            VALUES (new.id, COALESCE(new.content_plaintext, ''), COALESCE(new.summary, ''));
          END;
        SQL
      end

      dir.down do
        execute 'DROP TRIGGER IF EXISTS post_search_update;'
        execute 'DROP TRIGGER IF EXISTS post_search_delete;'
        execute 'DROP TRIGGER IF EXISTS post_search_insert;'
        execute 'DROP TABLE IF EXISTS post_search;'
      end
    end
  end
end
