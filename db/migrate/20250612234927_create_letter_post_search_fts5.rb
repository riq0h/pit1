# frozen_string_literal: true

class CreateLetterPostSearchFts5 < ActiveRecord::Migration[8.0]
  def up
    # FTS5仮想テーブル作成（letter_prefixで衝突回避）
    execute <<-SQL
      CREATE VIRTUAL TABLE letter_post_search USING fts5(
        object_id UNINDEXED,
        content_plaintext,
        summary
      );
    SQL

    # FTS5データ同期用トリガー作成
    execute <<-SQL
      CREATE TRIGGER letter_post_search_insert
      AFTER INSERT ON objects
      BEGIN
        INSERT INTO letter_post_search(object_id, content_plaintext, summary)
        VALUES (new.id, COALESCE(new.content_plaintext, ''), COALESCE(new.summary, ''));
      END;
    SQL

    execute <<-SQL
      CREATE TRIGGER letter_post_search_delete
      AFTER DELETE ON objects
      BEGIN
        DELETE FROM letter_post_search WHERE object_id = old.id;
      END;
    SQL

    execute <<-SQL
      CREATE TRIGGER letter_post_search_update
      AFTER UPDATE ON objects
      BEGIN
        DELETE FROM letter_post_search WHERE object_id = old.id;
        INSERT INTO letter_post_search(object_id, content_plaintext, summary)
        VALUES (new.id, COALESCE(new.content_plaintext, ''), COALESCE(new.summary, ''));
      END;
    SQL
  end

  def down
    execute 'DROP TRIGGER IF EXISTS letter_post_search_update;'
    execute 'DROP TRIGGER IF EXISTS letter_post_search_delete;'
    execute 'DROP TRIGGER IF EXISTS letter_post_search_insert;'
    execute 'DROP TABLE IF EXISTS letter_post_search;'
  end
end
