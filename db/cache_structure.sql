CREATE TABLE solid_cache_entries (id INTEGER PRIMARY KEY AUTOINCREMENT, key BLOB NOT NULL, value BLOB NOT NULL, created_at DATETIME NOT NULL, key_hash INTEGER NOT NULL, byte_size INTEGER NOT NULL);
CREATE UNIQUE INDEX index_solid_cache_entries_on_key_hash ON solid_cache_entries (key_hash) /*application='letter'*/;
CREATE INDEX index_solid_cache_entries_on_byte_size ON solid_cache_entries (byte_size) /*application='letter'*/;
CREATE INDEX index_solid_cache_entries_on_key_hash_and_byte_size ON solid_cache_entries (key_hash, byte_size) /*application='letter'*/;
CREATE TABLE IF NOT EXISTS "schema_migrations" ("version" varchar NOT NULL PRIMARY KEY);
CREATE TABLE IF NOT EXISTS "ar_internal_metadata" ("key" varchar NOT NULL PRIMARY KEY, "value" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);


