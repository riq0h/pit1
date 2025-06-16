# frozen_string_literal: true

class FixSearchDatabaseStructure < ActiveRecord::Migration[8.0]
  def up
    # 既存の問題のあるFTSテーブルとトリガーを削除
    execute 'DROP TRIGGER IF EXISTS post_search_insert;'
    execute 'DROP TRIGGER IF EXISTS post_search_update;'
    execute 'DROP TRIGGER IF EXISTS post_search_delete;'
    execute 'DROP TRIGGER IF EXISTS letter_post_search_insert;'
    execute 'DROP TRIGGER IF EXISTS letter_post_search_update;'
    execute 'DROP TRIGGER IF EXISTS letter_post_search_delete;'
    execute 'DROP TABLE IF EXISTS post_search;'
    execute 'DROP TABLE IF EXISTS letter_post_search;'

    # 新しいFTS5仮想テーブル作成（日本語検索対応）
    execute <<-SQL
      CREATE VIRTUAL TABLE object_search_fts USING fts5(
        object_id UNINDEXED,
        content_plaintext,
        summary,
        tokenize='porter unicode61'
      );
    SQL

    # 既存データをFTSテーブルに投入
    execute <<-SQL
      INSERT INTO object_search_fts(object_id, content_plaintext, summary)
      SELECT id, COALESCE(content_plaintext, ''), COALESCE(summary, '')
      FROM objects
      WHERE object_type = 'Note';
    SQL

    # データ同期用トリガー作成
    execute <<-SQL
      CREATE TRIGGER object_search_fts_insert
      AFTER INSERT ON objects
      WHEN new.object_type = 'Note'
      BEGIN
        INSERT INTO object_search_fts(object_id, content_plaintext, summary)
        VALUES (new.id, COALESCE(new.content_plaintext, ''), COALESCE(new.summary, ''));
      END;
    SQL

    execute <<-SQL
      CREATE TRIGGER object_search_fts_delete
      AFTER DELETE ON objects
      WHEN old.object_type = 'Note'
      BEGIN
        DELETE FROM object_search_fts WHERE object_id = old.id;
      END;
    SQL

    execute <<-SQL
      CREATE TRIGGER object_search_fts_update
      AFTER UPDATE ON objects
      WHEN new.object_type = 'Note'
      BEGIN
        DELETE FROM object_search_fts WHERE object_id = old.id;
        INSERT INTO object_search_fts(object_id, content_plaintext, summary)
        VALUES (new.id, COALESCE(new.content_plaintext, ''), COALESCE(new.summary, ''));
      END;
    SQL
  end

  def down
    execute 'DROP TRIGGER IF EXISTS object_search_fts_update;'
    execute 'DROP TRIGGER IF EXISTS object_search_fts_delete;'
    execute 'DROP TRIGGER IF EXISTS object_search_fts_insert;'
    execute 'DROP TABLE IF EXISTS object_search_fts;'
  end
end
