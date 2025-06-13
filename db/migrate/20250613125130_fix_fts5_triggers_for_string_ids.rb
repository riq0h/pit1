class FixFts5TriggersForStringIds < ActiveRecord::Migration[8.0]
  def up
    # Drop problematic old triggers
    execute "DROP TRIGGER IF EXISTS post_search_insert"
    execute "DROP TRIGGER IF EXISTS post_search_update"
    execute "DROP TRIGGER IF EXISTS post_search_delete"
    
    # The letter_post_search triggers work correctly with object_id as string
    # so we keep those. We only need to fix the old post_search triggers
    # that try to use string IDs as rowid (which must be integer)
    
    # Since post_search FTS5 table expects integer rowid but objects.id is string,
    # we'll disable the old post_search triggers entirely
    # The letter_post_search table uses object_id properly as string
    
    puts "Fixed FTS5 triggers for string IDs"
  end

  def down
    # Recreate original triggers (will cause same issues)
    execute <<~SQL
      CREATE TRIGGER post_search_insert 
      AFTER INSERT ON objects 
      BEGIN
        INSERT INTO post_search(rowid, content_plaintext, summary) 
        VALUES (new.id, COALESCE(new.content_plaintext, ''), COALESCE(new.summary, ''));
      END
    SQL
    
    execute <<~SQL
      CREATE TRIGGER post_search_update 
      AFTER UPDATE ON objects 
      BEGIN
        INSERT INTO post_search(post_search, rowid, content_plaintext, summary) 
        VALUES('delete', old.id, COALESCE(old.content_plaintext, ''), COALESCE(old.summary, ''));
        INSERT INTO post_search(rowid, content_plaintext, summary) 
        VALUES (new.id, COALESCE(new.content_plaintext, ''), COALESCE(new.summary, ''));
      END
    SQL
    
    execute <<~SQL
      CREATE TRIGGER post_search_delete 
      AFTER DELETE ON objects 
      BEGIN
        INSERT INTO post_search(post_search, rowid, content_plaintext, summary) 
        VALUES('delete', old.id, COALESCE(old.content_plaintext, ''), COALESCE(old.summary, ''));
      END
    SQL
  end
end