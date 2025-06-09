CREATE TABLE IF NOT EXISTS "schema_migrations" ("version" varchar NOT NULL PRIMARY KEY);
CREATE TABLE IF NOT EXISTS "ar_internal_metadata" ("key" varchar NOT NULL PRIMARY KEY, "value" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE TABLE IF NOT EXISTS "actors" ("id" varchar NOT NULL PRIMARY KEY, "username" varchar(20) NOT NULL, "domain" varchar(255), "display_name" varchar(100), "summary" text, "ap_id" varchar NOT NULL, "inbox_url" varchar NOT NULL, "outbox_url" varchar NOT NULL, "followers_url" varchar NOT NULL, "following_url" varchar NOT NULL, "public_key" text NOT NULL, "private_key" text, "avatar_url" varchar, "header_url" varchar, "local" boolean DEFAULT 0 NOT NULL, "locked" boolean DEFAULT 0 NOT NULL, "bot" boolean DEFAULT 0 NOT NULL, "suspended" boolean DEFAULT 0 NOT NULL, "local_account_slot" integer(1), "followers_count" integer DEFAULT 0 NOT NULL, "following_count" integer DEFAULT 0 NOT NULL, "posts_count" integer DEFAULT 0 NOT NULL, "raw_data" json, "last_fetched_at" datetime(6), "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "actor_type" varchar DEFAULT 'Person' /*application='Pit1'*/, "discoverable" boolean DEFAULT 1 /*application='Pit1'*/, "manually_approves_followers" boolean DEFAULT 0 /*application='Pit1'*/, "featured_url" varchar /*application='Pit1'*/, "icon_url" varchar /*application='Pit1'*/, "password_digest" varchar /*application='Pit1'*/);
CREATE UNIQUE INDEX "index_actors_on_ap_id" ON "actors" ("ap_id") /*application='Pit1'*/;
CREATE UNIQUE INDEX "index_actors_on_username_and_domain" ON "actors" ("username", "domain") /*application='Pit1'*/;
CREATE INDEX "index_actors_on_domain" ON "actors" ("domain") /*application='Pit1'*/;
CREATE INDEX "index_actors_on_local" ON "actors" ("local") /*application='Pit1'*/;
CREATE INDEX "index_actors_on_suspended" ON "actors" ("suspended") /*application='Pit1'*/;
CREATE UNIQUE INDEX "index_actors_on_local_and_local_account_slot" ON "actors" ("local", "local_account_slot") WHERE local = 1 /*application='Pit1'*/;
CREATE TRIGGER limit_local_actors
          BEFORE INSERT ON actors
          WHEN NEW.local = 1
          BEGIN
            -- 空いているスロット番号を自動割り当て
            UPDATE NEW SET local_account_slot = (
              CASE 
                WHEN NOT EXISTS (SELECT 1 FROM actors WHERE local = 1 AND local_account_slot = 1) THEN 1
                WHEN NOT EXISTS (SELECT 1 FROM actors WHERE local = 1 AND local_account_slot = 2) THEN 2
                ELSE RAISE(ABORT, 'This spaceship is a two-seater. Maximum 2 local accounts allowed.')
              END
            );
          END;
CREATE TABLE IF NOT EXISTS "activities" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "ap_id" varchar NOT NULL, "activity_type" varchar NOT NULL, "actor_id" integer NOT NULL, "object_id" integer, "target_ap_id" varchar, "raw_data" json, "published_at" datetime(6), "local" boolean DEFAULT 0, "processed" boolean DEFAULT 0, "processed_at" datetime(6), "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "delivered" boolean DEFAULT 0 NOT NULL /*application='Pit1'*/, "delivered_at" datetime(6) /*application='Pit1'*/, "delivery_attempts" integer DEFAULT 0 NOT NULL /*application='Pit1'*/, "last_delivery_error" text /*application='Pit1'*/, CONSTRAINT "fk_rails_5c0136e7dd"
FOREIGN KEY ("actor_id")
  REFERENCES "actors" ("id")
, CONSTRAINT "fk_rails_9cc4ea825d"
FOREIGN KEY ("object_id")
  REFERENCES "objects" ("id")
);
CREATE UNIQUE INDEX "index_activities_on_ap_id" ON "activities" ("ap_id") /*application='Pit1'*/;
CREATE INDEX "index_activities_on_actor_id" ON "activities" ("actor_id") /*application='Pit1'*/;
CREATE INDEX "index_activities_on_object_id" ON "activities" ("object_id") /*application='Pit1'*/;
CREATE INDEX "index_activities_on_activity_type" ON "activities" ("activity_type") /*application='Pit1'*/;
CREATE INDEX "index_activities_on_actor_id_and_published_at" ON "activities" ("actor_id", "published_at") /*application='Pit1'*/;
CREATE INDEX "index_activities_on_local" ON "activities" ("local") /*application='Pit1'*/;
CREATE INDEX "index_activities_on_processed" ON "activities" ("processed") /*application='Pit1'*/;
CREATE INDEX "index_activities_on_target_ap_id" ON "activities" ("target_ap_id") /*application='Pit1'*/;
CREATE TABLE IF NOT EXISTS "objects" ("id" varchar NOT NULL PRIMARY KEY, "ap_id" varchar NOT NULL, "object_type" varchar DEFAULT 'Note' NOT NULL, "actor_id" varchar NOT NULL, "content" text, "content_plaintext" text, "summary" text, "url" varchar, "language" varchar DEFAULT 'ja', "in_reply_to_ap_id" varchar, "conversation_ap_id" varchar, "media_type" varchar, "blurhash" varchar, "width" integer, "height" integer, "sensitive" boolean DEFAULT 0, "visibility" varchar DEFAULT 'public', "raw_data" json, "published_at" datetime(6), "local" boolean DEFAULT 0, "replies_count" integer DEFAULT 0, "reblogs_count" integer DEFAULT 0, "favourites_count" integer DEFAULT 0, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_1377a551fa"
FOREIGN KEY ("actor_id")
  REFERENCES "actors" ("id")
);
CREATE INDEX "index_objects_on_actor_id" ON "objects" ("actor_id") /*application='Pit1'*/;
CREATE UNIQUE INDEX "index_objects_on_ap_id" ON "objects" ("ap_id") /*application='Pit1'*/;
CREATE INDEX "index_objects_on_object_type" ON "objects" ("object_type") /*application='Pit1'*/;
CREATE INDEX "index_objects_on_published_at" ON "objects" ("published_at") /*application='Pit1'*/;
CREATE INDEX "index_objects_on_visibility" ON "objects" ("visibility") /*application='Pit1'*/;
CREATE INDEX "index_objects_on_local" ON "objects" ("local") /*application='Pit1'*/;
CREATE INDEX "index_objects_on_in_reply_to_ap_id" ON "objects" ("in_reply_to_ap_id") /*application='Pit1'*/;
CREATE INDEX "index_objects_on_conversation_ap_id" ON "objects" ("conversation_ap_id") /*application='Pit1'*/;
CREATE VIRTUAL TABLE post_search USING fts5(
            content_plaintext,
            summary,
            content='objects',
            content_rowid='id'
          )
/* post_search(content_plaintext,summary) */;
CREATE TABLE IF NOT EXISTS 'post_search_data'(id INTEGER PRIMARY KEY, block BLOB);
CREATE TABLE IF NOT EXISTS 'post_search_idx'(segid, term, pgno, PRIMARY KEY(segid, term)) WITHOUT ROWID;
CREATE TABLE IF NOT EXISTS 'post_search_docsize'(id INTEGER PRIMARY KEY, sz BLOB);
CREATE TABLE IF NOT EXISTS 'post_search_config'(k PRIMARY KEY, v) WITHOUT ROWID;
CREATE TRIGGER post_search_insert 
          AFTER INSERT ON objects 
          BEGIN
            INSERT INTO post_search(rowid, content_plaintext, summary) 
            VALUES (new.id, COALESCE(new.content_plaintext, ''), COALESCE(new.summary, ''));
          END;
CREATE TRIGGER post_search_delete 
          AFTER DELETE ON objects 
          BEGIN
            INSERT INTO post_search(post_search, rowid, content_plaintext, summary) 
            VALUES('delete', old.id, COALESCE(old.content_plaintext, ''), COALESCE(old.summary, ''));
          END;
CREATE TRIGGER post_search_update 
          AFTER UPDATE ON objects 
          BEGIN
            INSERT INTO post_search(post_search, rowid, content_plaintext, summary) 
            VALUES('delete', old.id, COALESCE(old.content_plaintext, ''), COALESCE(old.summary, ''));
            INSERT INTO post_search(rowid, content_plaintext, summary) 
            VALUES (new.id, COALESCE(new.content_plaintext, ''), COALESCE(new.summary, ''));
          END;
CREATE TABLE IF NOT EXISTS "follows" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "actor_id" integer NOT NULL, "target_actor_id" integer NOT NULL, "ap_id" varchar NOT NULL, "follow_activity_ap_id" varchar, "accept_activity_ap_id" varchar, "accepted" boolean DEFAULT 0, "accepted_at" datetime(6), "blocked" boolean DEFAULT 0, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_66a3328916"
FOREIGN KEY ("actor_id")
  REFERENCES "actors" ("id")
, CONSTRAINT "fk_rails_fd5b071a42"
FOREIGN KEY ("target_actor_id")
  REFERENCES "actors" ("id")
);
CREATE INDEX "index_follows_on_actor_id" ON "follows" ("actor_id") /*application='Pit1'*/;
CREATE INDEX "index_follows_on_target_actor_id" ON "follows" ("target_actor_id") /*application='Pit1'*/;
CREATE UNIQUE INDEX "index_follows_on_ap_id" ON "follows" ("ap_id") /*application='Pit1'*/;
CREATE UNIQUE INDEX "index_follows_on_actor_id_and_target_actor_id" ON "follows" ("actor_id", "target_actor_id") /*application='Pit1'*/;
CREATE INDEX "index_follows_on_accepted" ON "follows" ("accepted") /*application='Pit1'*/;
CREATE INDEX "index_follows_on_follow_activity_ap_id" ON "follows" ("follow_activity_ap_id") /*application='Pit1'*/;
CREATE TRIGGER follow_insert_update_counts
      AFTER INSERT ON follows
      WHEN NEW.accepted = 1
      BEGIN
        UPDATE actors SET following_count = following_count + 1 WHERE id = NEW.actor_id;
        UPDATE actors SET followers_count = followers_count + 1 WHERE id = NEW.target_actor_id;
      END;
CREATE TABLE IF NOT EXISTS "media_attachments" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "object_id" integer NOT NULL, "actor_id" integer NOT NULL, "file_name" varchar, "content_type" varchar, "file_size" bigint, "storage_path" varchar, "remote_url" varchar, "width" integer, "height" integer, "blurhash" varchar, "description" text, "attachment_type" varchar DEFAULT 'image', "processed" boolean DEFAULT 0, "metadata" json, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_7631462b85"
FOREIGN KEY ("object_id")
  REFERENCES "objects" ("id")
, CONSTRAINT "fk_rails_6612e6f1ee"
FOREIGN KEY ("actor_id")
  REFERENCES "actors" ("id")
);
CREATE INDEX "index_media_attachments_on_object_id" ON "media_attachments" ("object_id") /*application='Pit1'*/;
CREATE INDEX "index_media_attachments_on_actor_id" ON "media_attachments" ("actor_id") /*application='Pit1'*/;
CREATE INDEX "index_media_attachments_on_attachment_type" ON "media_attachments" ("attachment_type") /*application='Pit1'*/;
CREATE INDEX "index_media_attachments_on_processed" ON "media_attachments" ("processed") /*application='Pit1'*/;
CREATE INDEX "index_media_attachments_on_blurhash" ON "media_attachments" ("blurhash") /*application='Pit1'*/;
CREATE TABLE IF NOT EXISTS "user_limits" ("id" varchar NOT NULL PRIMARY KEY, "actor_id" varchar, "limit_type" varchar(50) NOT NULL, "limit_value" integer NOT NULL, "current_usage" integer DEFAULT 0 NOT NULL, "enabled" boolean DEFAULT 1 NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_1c7d473965"
FOREIGN KEY ("actor_id")
  REFERENCES "actors" ("id")
);
CREATE INDEX "index_user_limits_on_actor_id" ON "user_limits" ("actor_id") /*application='Pit1'*/;
CREATE UNIQUE INDEX "index_user_limits_on_actor_id_and_limit_type" ON "user_limits" ("actor_id", "limit_type") /*application='Pit1'*/;
CREATE INDEX "index_user_limits_on_limit_type" ON "user_limits" ("limit_type") /*application='Pit1'*/;
CREATE INDEX "index_user_limits_on_enabled" ON "user_limits" ("enabled") /*application='Pit1'*/;
CREATE INDEX "index_user_limits_on_system_limits" ON "user_limits" ("limit_type") WHERE actor_id IS NULL /*application='Pit1'*/;
CREATE INDEX "index_actors_on_actor_type" ON "actors" ("actor_type") /*application='Pit1'*/;
CREATE INDEX "index_actors_on_discoverable" ON "actors" ("discoverable") /*application='Pit1'*/;
CREATE INDEX "index_actors_on_manually_approves_followers" ON "actors" ("manually_approves_followers") /*application='Pit1'*/;
CREATE INDEX "index_activities_on_delivered" ON "activities" ("delivered") /*application='Pit1'*/;
CREATE INDEX "index_activities_on_delivered_at" ON "activities" ("delivered_at") /*application='Pit1'*/;
CREATE INDEX "index_activities_on_local_and_delivered" ON "activities" ("local", "delivered") /*application='Pit1'*/;
INSERT INTO "schema_migrations" (version) VALUES
('20250609124950'),
('20250609073837'),
('20250609072600'),
('20250604054724'),
('20250604054719'),
('20250604054712'),
('20250604054704'),
('20250604054655'),
('20250604054234');

