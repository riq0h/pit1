# frozen_string_literal: true

class CreateSearchSystem < ActiveRecord::Migration[8.0]
  def change
    # Full-text search using FTS5
    reversible do |dir|
      dir.up do
        # Create FTS5 virtual table for posts
        execute <<~SQL
          CREATE VIRTUAL TABLE letter_post_search_fts5 USING fts5(
            object_id UNINDEXED,
            content,
            content_plaintext,
            actor_username,
            content='letter_post_search',
            content_rowid='rowid'
          );
        SQL

        # Create content table for FTS5
        execute <<~SQL
          CREATE TABLE letter_post_search(
            rowid INTEGER PRIMARY KEY,
            object_id TEXT NOT NULL,
            content TEXT,
            content_plaintext TEXT,
            actor_username TEXT
          );
        SQL

        # Create triggers to maintain FTS5 index
        execute <<~SQL
          CREATE TRIGGER letter_post_search_ai AFTER INSERT ON letter_post_search BEGIN
            INSERT INTO letter_post_search_fts5(rowid, object_id, content, content_plaintext, actor_username)
            VALUES (new.rowid, new.object_id, new.content, new.content_plaintext, new.actor_username);
          END;
        SQL

        execute <<~SQL
          CREATE TRIGGER letter_post_search_ad AFTER DELETE ON letter_post_search BEGIN
            INSERT INTO letter_post_search_fts5(letter_post_search_fts5, rowid, object_id, content, content_plaintext, actor_username)
            VALUES('delete', old.rowid, old.object_id, old.content, old.content_plaintext, old.actor_username);
          END;
        SQL

        execute <<~SQL
          CREATE TRIGGER letter_post_search_au AFTER UPDATE ON letter_post_search BEGIN
            INSERT INTO letter_post_search_fts5(letter_post_search_fts5, rowid, object_id, content, content_plaintext, actor_username)
            VALUES('delete', old.rowid, old.object_id, old.content, old.content_plaintext, old.actor_username);
            INSERT INTO letter_post_search_fts5(rowid, object_id, content, content_plaintext, actor_username)
            VALUES (new.rowid, new.object_id, new.content, new.content_plaintext, new.actor_username);
          END;
        SQL

        # Create triggers on objects table to populate search data
        execute <<~SQL
          CREATE TRIGGER objects_search_insert AFTER INSERT ON objects
          WHEN NEW.object_type = 'Note' AND NEW.visibility = 'public'
          BEGIN
            INSERT INTO letter_post_search(object_id, content, content_plaintext, actor_username)
            SELECT NEW.id, NEW.content, NEW.content_plaintext, actors.username
            FROM actors WHERE actors.id = NEW.actor_id;
          END;
        SQL

        execute <<~SQL
          CREATE TRIGGER objects_search_update AFTER UPDATE ON objects
          WHEN NEW.object_type = 'Note' AND NEW.visibility = 'public'
          BEGIN
            DELETE FROM letter_post_search WHERE object_id = OLD.id;
            INSERT INTO letter_post_search(object_id, content, content_plaintext, actor_username)
            SELECT NEW.id, NEW.content, NEW.content_plaintext, actors.username
            FROM actors WHERE actors.id = NEW.actor_id;
          END;
        SQL

        execute <<~SQL
          CREATE TRIGGER objects_search_delete AFTER DELETE ON objects
          BEGIN
            DELETE FROM letter_post_search WHERE object_id = OLD.id;
          END;
        SQL
      end

      dir.down do
        execute "DROP TRIGGER IF EXISTS objects_search_delete;"
        execute "DROP TRIGGER IF EXISTS objects_search_update;"
        execute "DROP TRIGGER IF EXISTS objects_search_insert;"
        execute "DROP TRIGGER IF EXISTS letter_post_search_au;"
        execute "DROP TRIGGER IF EXISTS letter_post_search_ad;"
        execute "DROP TRIGGER IF EXISTS letter_post_search_ai;"
        execute "DROP TABLE IF EXISTS letter_post_search;"
        execute "DROP TABLE IF EXISTS letter_post_search_fts5;"
      end
    end
  end
end