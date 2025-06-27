CREATE TABLE IF NOT EXISTS "schema_migrations" ("version" varchar NOT NULL PRIMARY KEY);
CREATE TABLE IF NOT EXISTS "ar_internal_metadata" ("key" varchar NOT NULL PRIMARY KEY, "value" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE TABLE IF NOT EXISTS "actors" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "username" varchar NOT NULL, "domain" varchar, "display_name" varchar, "note" text, "ap_id" varchar NOT NULL, "inbox_url" varchar NOT NULL, "outbox_url" varchar NOT NULL, "followers_url" varchar, "following_url" varchar, "featured_url" varchar, "public_key" text, "private_key" text, "local" boolean DEFAULT 0 NOT NULL, "locked" boolean DEFAULT 0, "bot" boolean DEFAULT 0, "suspended" boolean DEFAULT 0, "admin" boolean DEFAULT 0, "fields" text, "followers_count" integer DEFAULT 0, "following_count" integer DEFAULT 0, "posts_count" integer DEFAULT 0, "raw_data" text, "actor_type" varchar DEFAULT 'Person', "discoverable" boolean DEFAULT 1, "manually_approves_followers" boolean DEFAULT 0, "password_digest" varchar, "settings" json DEFAULT '"{}"', "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE INDEX "index_actors_on_domain" ON "actors" ("domain") /*application='letter'*/;
CREATE UNIQUE INDEX "index_actors_on_ap_id" ON "actors" ("ap_id") /*application='letter'*/;
CREATE INDEX "index_actors_on_local" ON "actors" ("local") /*application='letter'*/;
CREATE UNIQUE INDEX "index_actors_on_username_and_domain" ON "actors" ("username", "domain") /*application='letter'*/;
CREATE INDEX "index_actors_on_username" ON "actors" ("username") /*application='letter'*/;
CREATE TABLE IF NOT EXISTS "activities" ("id" varchar NOT NULL PRIMARY KEY, "ap_id" varchar NOT NULL, "activity_type" varchar NOT NULL, "actor_id" integer NOT NULL, "object_ap_id" varchar, "target_ap_id" varchar, "raw_data" text, "published_at" datetime(6), "local" boolean DEFAULT 0, "processed" boolean DEFAULT 0, "processed_at" datetime(6), "delivered" boolean DEFAULT 0, "delivered_at" datetime(6), "delivery_attempts" integer DEFAULT 0, "last_delivery_error" text, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_5c0136e7dd"
FOREIGN KEY ("actor_id")
  REFERENCES "actors" ("id")
);
CREATE UNIQUE INDEX "index_activities_on_ap_id" ON "activities" ("ap_id") /*application='letter'*/;
CREATE INDEX "index_activities_on_activity_type" ON "activities" ("activity_type") /*application='letter'*/;
CREATE INDEX "index_activities_on_actor_id" ON "activities" ("actor_id") /*application='letter'*/;
CREATE INDEX "index_activities_on_object_ap_id" ON "activities" ("object_ap_id") /*application='letter'*/;
CREATE INDEX "index_activities_on_target_ap_id" ON "activities" ("target_ap_id") /*application='letter'*/;
CREATE INDEX "index_activities_on_published_at" ON "activities" ("published_at") /*application='letter'*/;
CREATE INDEX "index_activities_on_local" ON "activities" ("local") /*application='letter'*/;
CREATE INDEX "index_activities_on_processed" ON "activities" ("processed") /*application='letter'*/;
CREATE TABLE IF NOT EXISTS "status_edits" ("id" varchar NOT NULL PRIMARY KEY, "object_id" varchar NOT NULL, "content" text, "content_plaintext" text, "summary" text, "sensitive" boolean DEFAULT 0, "language" varchar, "media_ids" json, "media_descriptions" json, "poll_options" json, "created_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_96c168f4ad"
FOREIGN KEY ("object_id")
  REFERENCES "objects" ("id")
);
CREATE INDEX "index_status_edits_on_object_id" ON "status_edits" ("object_id") /*application='letter'*/;
CREATE INDEX "index_status_edits_on_created_at" ON "status_edits" ("created_at") /*application='letter'*/;
CREATE INDEX "index_status_edits_on_object_id_and_created_at" ON "status_edits" ("object_id", "created_at") /*application='letter'*/;
CREATE TABLE IF NOT EXISTS "relays" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "inbox_url" varchar NOT NULL, "state" varchar DEFAULT 'idle' NOT NULL, "follow_activity_id" varchar, "followed_at" datetime(6), "last_error" text, "delivery_attempts" integer DEFAULT 0, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE UNIQUE INDEX "index_relays_on_inbox_url" ON "relays" ("inbox_url") /*application='letter'*/;
CREATE INDEX "index_relays_on_state" ON "relays" ("state") /*application='letter'*/;
CREATE INDEX "index_relays_on_follow_activity_id" ON "relays" ("follow_activity_id") /*application='letter'*/;
CREATE TABLE IF NOT EXISTS "link_previews" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "url" varchar NOT NULL, "title" varchar, "description" text, "image" varchar, "site_name" varchar, "preview_type" varchar DEFAULT 'website', "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE UNIQUE INDEX "index_link_previews_on_url" ON "link_previews" ("url") /*application='letter'*/;
CREATE TABLE IF NOT EXISTS "follows" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "actor_id" integer NOT NULL, "target_actor_id" integer NOT NULL, "ap_id" varchar, "follow_activity_ap_id" varchar, "accepted" boolean DEFAULT 0, "accepted_at" datetime(6), "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_66a3328916"
FOREIGN KEY ("actor_id")
  REFERENCES "actors" ("id")
, CONSTRAINT "fk_rails_fd5b071a42"
FOREIGN KEY ("target_actor_id")
  REFERENCES "actors" ("id")
);
CREATE INDEX "index_follows_on_actor_id" ON "follows" ("actor_id") /*application='letter'*/;
CREATE INDEX "index_follows_on_target_actor_id" ON "follows" ("target_actor_id") /*application='letter'*/;
CREATE UNIQUE INDEX "index_follows_on_ap_id" ON "follows" ("ap_id") /*application='letter'*/;
CREATE UNIQUE INDEX "index_follows_on_follow_activity_ap_id" ON "follows" ("follow_activity_ap_id") /*application='letter'*/;
CREATE INDEX "index_follows_on_accepted" ON "follows" ("accepted") /*application='letter'*/;
CREATE UNIQUE INDEX "index_follows_on_actor_id_and_target_actor_id" ON "follows" ("actor_id", "target_actor_id") /*application='letter'*/;
CREATE TABLE IF NOT EXISTS "blocks" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "actor_id" integer NOT NULL, "target_actor_id" integer NOT NULL, "ap_id" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_015885e298"
FOREIGN KEY ("actor_id")
  REFERENCES "actors" ("id")
, CONSTRAINT "fk_rails_5bd836e0fd"
FOREIGN KEY ("target_actor_id")
  REFERENCES "actors" ("id")
);
CREATE INDEX "index_blocks_on_actor_id" ON "blocks" ("actor_id") /*application='letter'*/;
CREATE INDEX "index_blocks_on_target_actor_id" ON "blocks" ("target_actor_id") /*application='letter'*/;
CREATE UNIQUE INDEX "index_blocks_on_ap_id" ON "blocks" ("ap_id") /*application='letter'*/;
CREATE UNIQUE INDEX "index_blocks_on_actor_id_and_target_actor_id" ON "blocks" ("actor_id", "target_actor_id") /*application='letter'*/;
CREATE TABLE IF NOT EXISTS "mutes" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "actor_id" integer NOT NULL, "target_actor_id" integer NOT NULL, "ap_id" varchar, "notifications" boolean DEFAULT 1, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_bcd731dacd"
FOREIGN KEY ("actor_id")
  REFERENCES "actors" ("id")
, CONSTRAINT "fk_rails_caa1aeaa2a"
FOREIGN KEY ("target_actor_id")
  REFERENCES "actors" ("id")
);
CREATE INDEX "index_mutes_on_actor_id" ON "mutes" ("actor_id") /*application='letter'*/;
CREATE INDEX "index_mutes_on_target_actor_id" ON "mutes" ("target_actor_id") /*application='letter'*/;
CREATE UNIQUE INDEX "index_mutes_on_ap_id" ON "mutes" ("ap_id") /*application='letter'*/;
CREATE UNIQUE INDEX "index_mutes_on_actor_id_and_target_actor_id" ON "mutes" ("actor_id", "target_actor_id") /*application='letter'*/;
CREATE TABLE IF NOT EXISTS "domain_blocks" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "actor_id" integer NOT NULL, "domain" varchar NOT NULL, "reason" text, "reject_media" boolean DEFAULT 0, "reject_reports" boolean DEFAULT 0, "private_comment" boolean, "public_comment" text, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_ceda607ae5"
FOREIGN KEY ("actor_id")
  REFERENCES "actors" ("id")
);
CREATE INDEX "index_domain_blocks_on_actor_id" ON "domain_blocks" ("actor_id") /*application='letter'*/;
CREATE UNIQUE INDEX "index_domain_blocks_on_actor_id_and_domain" ON "domain_blocks" ("actor_id", "domain") /*application='letter'*/;
CREATE TABLE IF NOT EXISTS "account_notes" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "actor_id" integer NOT NULL, "target_actor_id" integer NOT NULL, "comment" text DEFAULT '' NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_1dd1c5b6a3"
FOREIGN KEY ("actor_id")
  REFERENCES "actors" ("id")
, CONSTRAINT "fk_rails_69861cf46b"
FOREIGN KEY ("target_actor_id")
  REFERENCES "actors" ("id")
);
CREATE INDEX "index_account_notes_on_actor_id" ON "account_notes" ("actor_id") /*application='letter'*/;
CREATE INDEX "index_account_notes_on_target_actor_id" ON "account_notes" ("target_actor_id") /*application='letter'*/;
CREATE UNIQUE INDEX "index_account_notes_on_actor_id_and_target_actor_id" ON "account_notes" ("actor_id", "target_actor_id") /*application='letter'*/;
CREATE TABLE IF NOT EXISTS "favourites" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "actor_id" integer NOT NULL, "object_id" varchar NOT NULL, "ap_id" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_757549d945"
FOREIGN KEY ("actor_id")
  REFERENCES "actors" ("id")
, CONSTRAINT "fk_rails_868448e3f7"
FOREIGN KEY ("object_id")
  REFERENCES "objects" ("id")
);
CREATE INDEX "index_favourites_on_actor_id" ON "favourites" ("actor_id") /*application='letter'*/;
CREATE INDEX "index_favourites_on_object_id" ON "favourites" ("object_id") /*application='letter'*/;
CREATE UNIQUE INDEX "index_favourites_on_ap_id" ON "favourites" ("ap_id") /*application='letter'*/;
CREATE UNIQUE INDEX "index_favourites_on_actor_id_and_object_id" ON "favourites" ("actor_id", "object_id") /*application='letter'*/;
CREATE TABLE IF NOT EXISTS "reblogs" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "actor_id" integer NOT NULL, "object_id" varchar NOT NULL, "ap_id" varchar, "visibility" varchar DEFAULT 'public', "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_16704774d5"
FOREIGN KEY ("actor_id")
  REFERENCES "actors" ("id")
, CONSTRAINT "fk_rails_f85b673d2b"
FOREIGN KEY ("object_id")
  REFERENCES "objects" ("id")
);
CREATE INDEX "index_reblogs_on_actor_id" ON "reblogs" ("actor_id") /*application='letter'*/;
CREATE INDEX "index_reblogs_on_object_id" ON "reblogs" ("object_id") /*application='letter'*/;
CREATE UNIQUE INDEX "index_reblogs_on_ap_id" ON "reblogs" ("ap_id") /*application='letter'*/;
CREATE UNIQUE INDEX "index_reblogs_on_actor_id_and_object_id" ON "reblogs" ("actor_id", "object_id") /*application='letter'*/;
CREATE TABLE IF NOT EXISTS "tags" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "name" varchar NOT NULL, "usage_count" integer DEFAULT 0, "trending" boolean DEFAULT 0, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE UNIQUE INDEX "index_tags_on_name" ON "tags" ("name") /*application='letter'*/;
CREATE TABLE IF NOT EXISTS "object_tags" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "object_id" varchar NOT NULL, "tag_id" integer NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_8f6810534c"
FOREIGN KEY ("tag_id")
  REFERENCES "tags" ("id")
, CONSTRAINT "fk_rails_11c6375210"
FOREIGN KEY ("object_id")
  REFERENCES "objects" ("id")
);
CREATE INDEX "index_object_tags_on_object_id" ON "object_tags" ("object_id") /*application='letter'*/;
CREATE INDEX "index_object_tags_on_tag_id" ON "object_tags" ("tag_id") /*application='letter'*/;
CREATE UNIQUE INDEX "index_object_tags_on_object_id_and_tag_id" ON "object_tags" ("object_id", "tag_id") /*application='letter'*/;
CREATE TABLE IF NOT EXISTS "featured_tags" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "actor_id" integer NOT NULL, "tag_id" integer NOT NULL, "statuses_count" integer DEFAULT 0 NOT NULL, "last_status_at" datetime(6), "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_1402769d77"
FOREIGN KEY ("actor_id")
  REFERENCES "actors" ("id")
, CONSTRAINT "fk_rails_23a9055c7c"
FOREIGN KEY ("tag_id")
  REFERENCES "tags" ("id")
);
CREATE INDEX "index_featured_tags_on_actor_id" ON "featured_tags" ("actor_id") /*application='letter'*/;
CREATE INDEX "index_featured_tags_on_tag_id" ON "featured_tags" ("tag_id") /*application='letter'*/;
CREATE UNIQUE INDEX "index_featured_tags_on_actor_id_and_tag_id" ON "featured_tags" ("actor_id", "tag_id") /*application='letter'*/;
CREATE TABLE IF NOT EXISTS "followed_tags" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "actor_id" integer NOT NULL, "tag_id" integer NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_117eec4622"
FOREIGN KEY ("actor_id")
  REFERENCES "actors" ("id")
, CONSTRAINT "fk_rails_255df44449"
FOREIGN KEY ("tag_id")
  REFERENCES "tags" ("id")
);
CREATE INDEX "index_followed_tags_on_actor_id" ON "followed_tags" ("actor_id") /*application='letter'*/;
CREATE INDEX "index_followed_tags_on_tag_id" ON "followed_tags" ("tag_id") /*application='letter'*/;
CREATE UNIQUE INDEX "index_followed_tags_on_actor_id_and_tag_id" ON "followed_tags" ("actor_id", "tag_id") /*application='letter'*/;
CREATE TABLE IF NOT EXISTS "quote_posts" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "object_id" varchar NOT NULL, "quoted_object_id" varchar NOT NULL, "actor_id" integer NOT NULL, "shallow_quote" boolean DEFAULT 0 NOT NULL, "quote_text" text, "ap_id" varchar, "visibility" varchar DEFAULT 'public', "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_adedfdd0ad"
FOREIGN KEY ("object_id")
  REFERENCES "objects" ("id")
, CONSTRAINT "fk_rails_ff36914c5b"
FOREIGN KEY ("actor_id")
  REFERENCES "actors" ("id")
, CONSTRAINT "fk_rails_aa3e8ec98a"
FOREIGN KEY ("quoted_object_id")
  REFERENCES "objects" ("id")
);
CREATE INDEX "index_quote_posts_on_actor_id" ON "quote_posts" ("actor_id") /*application='letter'*/;
CREATE UNIQUE INDEX "index_quote_posts_on_ap_id" ON "quote_posts" ("ap_id") /*application='letter'*/;
CREATE INDEX "index_quote_posts_on_object_id" ON "quote_posts" ("object_id") /*application='letter'*/;
CREATE INDEX "index_quote_posts_on_quoted_object_id" ON "quote_posts" ("quoted_object_id") /*application='letter'*/;
CREATE UNIQUE INDEX "index_quote_posts_on_object_id_and_quoted_object_id" ON "quote_posts" ("object_id", "quoted_object_id") /*application='letter'*/;
CREATE TABLE IF NOT EXISTS "mentions" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "object_id" varchar NOT NULL, "actor_id" integer NOT NULL, "ap_id" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_227016d488"
FOREIGN KEY ("actor_id")
  REFERENCES "actors" ("id")
, CONSTRAINT "fk_rails_6a4030f320"
FOREIGN KEY ("object_id")
  REFERENCES "objects" ("id")
);
CREATE INDEX "index_mentions_on_object_id" ON "mentions" ("object_id") /*application='letter'*/;
CREATE INDEX "index_mentions_on_actor_id" ON "mentions" ("actor_id") /*application='letter'*/;
CREATE UNIQUE INDEX "index_mentions_on_ap_id" ON "mentions" ("ap_id") /*application='letter'*/;
CREATE UNIQUE INDEX "index_mentions_on_object_id_and_actor_id" ON "mentions" ("object_id", "actor_id") /*application='letter'*/;
CREATE TABLE IF NOT EXISTS "bookmarks" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "actor_id" integer NOT NULL, "object_id" varchar NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_c7ac1d2d47"
FOREIGN KEY ("actor_id")
  REFERENCES "actors" ("id")
, CONSTRAINT "fk_rails_43ec798f5c"
FOREIGN KEY ("object_id")
  REFERENCES "objects" ("id")
);
CREATE INDEX "index_bookmarks_on_actor_id" ON "bookmarks" ("actor_id") /*application='letter'*/;
CREATE INDEX "index_bookmarks_on_object_id" ON "bookmarks" ("object_id") /*application='letter'*/;
CREATE UNIQUE INDEX "index_bookmarks_on_actor_id_and_object_id" ON "bookmarks" ("actor_id", "object_id") /*application='letter'*/;
CREATE TABLE IF NOT EXISTS "pinned_statuses" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "actor_id" integer NOT NULL, "object_id" varchar NOT NULL, "position" integer DEFAULT 0 NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_cb9d3b0e27"
FOREIGN KEY ("actor_id")
  REFERENCES "actors" ("id")
, CONSTRAINT "fk_rails_7b40b3ffcd"
FOREIGN KEY ("object_id")
  REFERENCES "objects" ("id")
);
CREATE INDEX "index_pinned_statuses_on_actor_id" ON "pinned_statuses" ("actor_id") /*application='letter'*/;
CREATE INDEX "index_pinned_statuses_on_object_id" ON "pinned_statuses" ("object_id") /*application='letter'*/;
CREATE UNIQUE INDEX "index_pinned_statuses_on_actor_id_and_object_id" ON "pinned_statuses" ("actor_id", "object_id") /*application='letter'*/;
CREATE INDEX "index_pinned_statuses_on_actor_id_and_position" ON "pinned_statuses" ("actor_id", "position") /*application='letter'*/;
CREATE TABLE IF NOT EXISTS "lists" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "actor_id" integer NOT NULL, "title" varchar NOT NULL, "replies_policy" varchar DEFAULT 'list' NOT NULL, "exclusive" boolean DEFAULT 0 NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_7276e87653"
FOREIGN KEY ("actor_id")
  REFERENCES "actors" ("id")
);
CREATE INDEX "index_lists_on_actor_id" ON "lists" ("actor_id") /*application='letter'*/;
CREATE TABLE IF NOT EXISTS "list_memberships" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "list_id" integer NOT NULL, "actor_id" integer NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_4ac06d7f64"
FOREIGN KEY ("list_id")
  REFERENCES "lists" ("id")
, CONSTRAINT "fk_rails_f2ceecde52"
FOREIGN KEY ("actor_id")
  REFERENCES "actors" ("id")
);
CREATE INDEX "index_list_memberships_on_list_id" ON "list_memberships" ("list_id") /*application='letter'*/;
CREATE INDEX "index_list_memberships_on_actor_id" ON "list_memberships" ("actor_id") /*application='letter'*/;
CREATE UNIQUE INDEX "index_list_memberships_on_list_id_and_actor_id" ON "list_memberships" ("list_id", "actor_id") /*application='letter'*/;
CREATE TABLE IF NOT EXISTS "media_attachments" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "actor_id" integer NOT NULL, "object_id" varchar, "media_type" varchar NOT NULL, "url" varchar, "remote_url" varchar, "thumbnail_url" varchar, "file_name" varchar, "file_size" integer, "content_type" varchar, "width" integer, "height" integer, "blurhash" varchar, "description" text, "metadata" text, "processing_status" varchar DEFAULT 'pending', "processed" boolean DEFAULT 0, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_6612e6f1ee"
FOREIGN KEY ("actor_id")
  REFERENCES "actors" ("id")
, CONSTRAINT "fk_rails_7631462b85"
FOREIGN KEY ("object_id")
  REFERENCES "objects" ("id")
);
CREATE INDEX "index_media_attachments_on_actor_id" ON "media_attachments" ("actor_id") /*application='letter'*/;
CREATE INDEX "index_media_attachments_on_object_id" ON "media_attachments" ("object_id") /*application='letter'*/;
CREATE TABLE IF NOT EXISTS "custom_emojis" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "shortcode" varchar NOT NULL, "domain" varchar, "uri" varchar, "image_url" varchar, "visible_in_picker" boolean DEFAULT 1, "disabled" boolean DEFAULT 0, "category_id" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE UNIQUE INDEX "index_custom_emojis_on_shortcode_and_domain" ON "custom_emojis" ("shortcode", "domain") /*application='letter'*/;
CREATE INDEX "index_custom_emojis_on_shortcode" ON "custom_emojis" ("shortcode") /*application='letter'*/;
CREATE TABLE IF NOT EXISTS "conversations" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "ap_id" varchar, "subject" varchar, "local" boolean DEFAULT 1, "unread" boolean DEFAULT 0, "last_message_at" datetime(6), "last_status_id" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE UNIQUE INDEX "index_conversations_on_ap_id" ON "conversations" ("ap_id") /*application='letter'*/;
CREATE INDEX "index_conversations_on_last_message_at" ON "conversations" ("last_message_at") /*application='letter'*/;
CREATE TABLE IF NOT EXISTS "conversation_participants" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "conversation_id" integer NOT NULL, "actor_id" integer NOT NULL, "active" boolean DEFAULT 1, "last_read_at" datetime(6), "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_d4fdd4cae0"
FOREIGN KEY ("conversation_id")
  REFERENCES "conversations" ("id")
, CONSTRAINT "fk_rails_883f0f1aba"
FOREIGN KEY ("actor_id")
  REFERENCES "actors" ("id")
);
CREATE INDEX "index_conversation_participants_on_conversation_id" ON "conversation_participants" ("conversation_id") /*application='letter'*/;
CREATE INDEX "index_conversation_participants_on_actor_id" ON "conversation_participants" ("actor_id") /*application='letter'*/;
CREATE UNIQUE INDEX "idx_on_conversation_id_actor_id_a90cdc69d4" ON "conversation_participants" ("conversation_id", "actor_id") /*application='letter'*/;
CREATE TABLE IF NOT EXISTS "objects" ("id" varchar NOT NULL PRIMARY KEY, "ap_id" varchar NOT NULL, "object_type" varchar NOT NULL, "actor_id" integer NOT NULL, "content" text, "content_plaintext" text, "summary" text, "url" varchar, "language" varchar, "sensitive" boolean DEFAULT 0, "visibility" varchar DEFAULT 'public', "raw_data" text, "published_at" datetime(6), "local" boolean DEFAULT 0, "is_pinned_only" boolean DEFAULT 0, "relay_id" integer, "replies_count" integer DEFAULT 0, "reblogs_count" integer DEFAULT 0, "favourites_count" integer DEFAULT 0, "edited_at" datetime(6), "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "in_reply_to_ap_id" varchar, "conversation_ap_id" varchar, "conversation_id" integer, CONSTRAINT "fk_rails_73fd572a5f"
FOREIGN KEY ("relay_id")
  REFERENCES "relays" ("id")
, CONSTRAINT "fk_rails_1377a551fa"
FOREIGN KEY ("actor_id")
  REFERENCES "actors" ("id")
, CONSTRAINT "fk_rails_eb0aea9dca"
FOREIGN KEY ("conversation_id")
  REFERENCES "conversations" ("id")
);
CREATE UNIQUE INDEX "index_objects_on_ap_id" ON "objects" ("ap_id") /*application='letter'*/;
CREATE INDEX "index_objects_on_object_type" ON "objects" ("object_type") /*application='letter'*/;
CREATE INDEX "index_objects_on_actor_id" ON "objects" ("actor_id") /*application='letter'*/;
CREATE INDEX "index_objects_on_visibility" ON "objects" ("visibility") /*application='letter'*/;
CREATE INDEX "index_objects_on_published_at" ON "objects" ("published_at") /*application='letter'*/;
CREATE INDEX "index_objects_on_local" ON "objects" ("local") /*application='letter'*/;
CREATE INDEX "index_objects_on_is_pinned_only" ON "objects" ("is_pinned_only") /*application='letter'*/;
CREATE INDEX "index_objects_on_relay_id" ON "objects" ("relay_id") /*application='letter'*/;
CREATE INDEX "index_objects_on_edited_at" ON "objects" ("edited_at") /*application='letter'*/;
CREATE INDEX "index_objects_on_in_reply_to_ap_id" ON "objects" ("in_reply_to_ap_id") /*application='letter'*/;
CREATE INDEX "index_objects_on_conversation_ap_id" ON "objects" ("conversation_ap_id") /*application='letter'*/;
CREATE INDEX "index_objects_on_conversation_id" ON "objects" ("conversation_id") /*application='letter'*/;
CREATE TABLE IF NOT EXISTS "user_limits" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "actor_id" integer NOT NULL, "limit_type" varchar NOT NULL, "limit_value" integer NOT NULL, "current_usage" integer DEFAULT 0, "reset_at" datetime(6), "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_1c7d473965"
FOREIGN KEY ("actor_id")
  REFERENCES "actors" ("id")
);
CREATE UNIQUE INDEX "index_user_limits_on_actor_id" ON "user_limits" ("actor_id") /*application='letter'*/;
CREATE UNIQUE INDEX "index_user_limits_on_actor_id_and_limit_type" ON "user_limits" ("actor_id", "limit_type") /*application='letter'*/;
CREATE TABLE IF NOT EXISTS "filters" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "actor_id" integer NOT NULL, "title" varchar NOT NULL, "context" text NOT NULL, "expires_at" datetime(6), "filter_action" varchar DEFAULT 'warn' NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_addf0d240f"
FOREIGN KEY ("actor_id")
  REFERENCES "actors" ("id")
);
CREATE INDEX "index_filters_on_actor_id" ON "filters" ("actor_id") /*application='letter'*/;
CREATE TABLE IF NOT EXISTS "filter_keywords" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "filter_id" integer NOT NULL, "keyword" varchar NOT NULL, "whole_word" boolean DEFAULT 0 NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_1ccc5ec936"
FOREIGN KEY ("filter_id")
  REFERENCES "filters" ("id")
);
CREATE INDEX "index_filter_keywords_on_filter_id" ON "filter_keywords" ("filter_id") /*application='letter'*/;
CREATE UNIQUE INDEX "index_filter_keywords_on_filter_id_and_keyword" ON "filter_keywords" ("filter_id", "keyword") /*application='letter'*/;
CREATE TABLE IF NOT EXISTS "filter_statuses" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "filter_id" integer NOT NULL, "status_id" varchar NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_a67978252f"
FOREIGN KEY ("filter_id")
  REFERENCES "filters" ("id")
, CONSTRAINT "fk_rails_50cc61738b"
FOREIGN KEY ("status_id")
  REFERENCES "objects" ("id")
);
CREATE INDEX "index_filter_statuses_on_filter_id" ON "filter_statuses" ("filter_id") /*application='letter'*/;
CREATE INDEX "index_filter_statuses_on_status_id" ON "filter_statuses" ("status_id") /*application='letter'*/;
CREATE UNIQUE INDEX "index_filter_statuses_on_filter_id_and_status_id" ON "filter_statuses" ("filter_id", "status_id") /*application='letter'*/;
CREATE TABLE IF NOT EXISTS "web_push_subscriptions" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "actor_id" integer NOT NULL, "endpoint" varchar NOT NULL, "p256dh_key" varchar NOT NULL, "auth_key" varchar NOT NULL, "data" text, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_df8c8bc4c1"
FOREIGN KEY ("actor_id")
  REFERENCES "actors" ("id")
);
CREATE INDEX "index_web_push_subscriptions_on_actor_id" ON "web_push_subscriptions" ("actor_id") /*application='letter'*/;
CREATE UNIQUE INDEX "index_web_push_subscriptions_on_actor_id_and_endpoint" ON "web_push_subscriptions" ("actor_id", "endpoint") /*application='letter'*/;
CREATE TABLE IF NOT EXISTS "markers" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "actor_id" integer NOT NULL, "timeline" varchar NOT NULL, "last_read_id" varchar NOT NULL, "version" integer DEFAULT 1 NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_474765557e"
FOREIGN KEY ("actor_id")
  REFERENCES "actors" ("id")
);
CREATE INDEX "index_markers_on_actor_id" ON "markers" ("actor_id") /*application='letter'*/;
CREATE UNIQUE INDEX "index_markers_on_actor_id_and_timeline" ON "markers" ("actor_id", "timeline") /*application='letter'*/;
CREATE TABLE IF NOT EXISTS "announcements" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "content" text NOT NULL, "starts_at" datetime(6), "ends_at" datetime(6), "published" boolean DEFAULT 0 NOT NULL, "all_day" boolean DEFAULT 0 NOT NULL, "published_at" datetime(6), "mentions" json, "statuses" json, "tags" json, "emojis" json, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE TABLE IF NOT EXISTS "announcement_reactions" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "announcement_id" integer NOT NULL, "actor_id" integer NOT NULL, "name" varchar NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_a1226eaa5c"
FOREIGN KEY ("announcement_id")
  REFERENCES "announcements" ("id")
, CONSTRAINT "fk_rails_1850eb8106"
FOREIGN KEY ("actor_id")
  REFERENCES "actors" ("id")
);
CREATE INDEX "index_announcement_reactions_on_announcement_id" ON "announcement_reactions" ("announcement_id") /*application='letter'*/;
CREATE INDEX "index_announcement_reactions_on_actor_id" ON "announcement_reactions" ("actor_id") /*application='letter'*/;
CREATE UNIQUE INDEX "idx_on_announcement_id_actor_id_name_02cf634df5" ON "announcement_reactions" ("announcement_id", "actor_id", "name") /*application='letter'*/;
CREATE TABLE IF NOT EXISTS "announcement_dismissals" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "announcement_id" integer NOT NULL, "actor_id" integer NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_c290f2d124"
FOREIGN KEY ("announcement_id")
  REFERENCES "announcements" ("id")
, CONSTRAINT "fk_rails_25ed0c754e"
FOREIGN KEY ("actor_id")
  REFERENCES "actors" ("id")
);
CREATE INDEX "index_announcement_dismissals_on_announcement_id" ON "announcement_dismissals" ("announcement_id") /*application='letter'*/;
CREATE INDEX "index_announcement_dismissals_on_actor_id" ON "announcement_dismissals" ("actor_id") /*application='letter'*/;
CREATE UNIQUE INDEX "index_announcement_dismissals_on_announcement_id_and_actor_id" ON "announcement_dismissals" ("announcement_id", "actor_id") /*application='letter'*/;
CREATE TABLE IF NOT EXISTS "reports" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "reporter_id" integer NOT NULL, "target_account_id" integer NOT NULL, "status_ids" json, "comment" text, "category" varchar DEFAULT 'other', "forwarded" boolean DEFAULT 0, "action_taken" boolean DEFAULT 0, "action_taken_at" datetime(6), "rule_ids" json, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_c4cb6e6463"
FOREIGN KEY ("reporter_id")
  REFERENCES "actors" ("id")
, CONSTRAINT "fk_rails_66528197fd"
FOREIGN KEY ("target_account_id")
  REFERENCES "actors" ("id")
);
CREATE INDEX "index_reports_on_reporter_id" ON "reports" ("reporter_id") /*application='letter'*/;
CREATE INDEX "index_reports_on_target_account_id" ON "reports" ("target_account_id") /*application='letter'*/;
CREATE TABLE IF NOT EXISTS "polls" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "object_id" varchar NOT NULL, "expires_at" datetime(6) NOT NULL, "multiple" boolean DEFAULT 0 NOT NULL, "votes_count" integer DEFAULT 0 NOT NULL, "voters_count" integer DEFAULT 0, "options" json NOT NULL, "hide_totals" boolean DEFAULT 0 NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_bb7c29f20c"
FOREIGN KEY ("object_id")
  REFERENCES "objects" ("id")
);
CREATE INDEX "index_polls_on_object_id" ON "polls" ("object_id") /*application='letter'*/;
CREATE TABLE IF NOT EXISTS "poll_votes" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "poll_id" integer NOT NULL, "actor_id" integer NOT NULL, "choice" integer NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_a6e6974b7e"
FOREIGN KEY ("poll_id")
  REFERENCES "polls" ("id")
, CONSTRAINT "fk_rails_a029c85985"
FOREIGN KEY ("actor_id")
  REFERENCES "actors" ("id")
);
CREATE INDEX "index_poll_votes_on_poll_id" ON "poll_votes" ("poll_id") /*application='letter'*/;
CREATE INDEX "index_poll_votes_on_actor_id" ON "poll_votes" ("actor_id") /*application='letter'*/;
CREATE UNIQUE INDEX "index_poll_votes_on_poll_id_and_actor_id_and_choice" ON "poll_votes" ("poll_id", "actor_id", "choice") /*application='letter'*/;
CREATE TABLE IF NOT EXISTS "scheduled_statuses" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "actor_id" integer NOT NULL, "scheduled_at" datetime(6) NOT NULL, "params" json NOT NULL, "media_attachment_ids" json, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_557f5f655f"
FOREIGN KEY ("actor_id")
  REFERENCES "actors" ("id")
);
CREATE INDEX "index_scheduled_statuses_on_actor_id" ON "scheduled_statuses" ("actor_id") /*application='letter'*/;
CREATE INDEX "index_scheduled_statuses_on_scheduled_at" ON "scheduled_statuses" ("scheduled_at") /*application='letter'*/;
CREATE VIRTUAL TABLE letter_post_search_fts5 USING fts5(
  object_id UNINDEXED,
  content,
  content_plaintext,
  actor_username,
  content='letter_post_search',
  content_rowid='rowid'
)
/* letter_post_search_fts5(object_id,content,content_plaintext,actor_username) */;
CREATE TABLE IF NOT EXISTS 'letter_post_search_fts5_data'(id INTEGER PRIMARY KEY, block BLOB);
CREATE TABLE IF NOT EXISTS 'letter_post_search_fts5_idx'(segid, term, pgno, PRIMARY KEY(segid, term)) WITHOUT ROWID;
CREATE TABLE IF NOT EXISTS 'letter_post_search_fts5_docsize'(id INTEGER PRIMARY KEY, sz BLOB);
CREATE TABLE IF NOT EXISTS 'letter_post_search_fts5_config'(k PRIMARY KEY, v) WITHOUT ROWID;
CREATE TABLE letter_post_search(
  rowid INTEGER PRIMARY KEY,
  object_id TEXT NOT NULL,
  content TEXT,
  content_plaintext TEXT,
  actor_username TEXT
);
CREATE TRIGGER letter_post_search_ai AFTER INSERT ON letter_post_search BEGIN
  INSERT INTO letter_post_search_fts5(rowid, object_id, content, content_plaintext, actor_username)
  VALUES (new.rowid, new.object_id, new.content, new.content_plaintext, new.actor_username);
END;
CREATE TRIGGER letter_post_search_ad AFTER DELETE ON letter_post_search BEGIN
  INSERT INTO letter_post_search_fts5(letter_post_search_fts5, rowid, object_id, content, content_plaintext, actor_username)
  VALUES('delete', old.rowid, old.object_id, old.content, old.content_plaintext, old.actor_username);
END;
CREATE TRIGGER letter_post_search_au AFTER UPDATE ON letter_post_search BEGIN
  INSERT INTO letter_post_search_fts5(letter_post_search_fts5, rowid, object_id, content, content_plaintext, actor_username)
  VALUES('delete', old.rowid, old.object_id, old.content, old.content_plaintext, old.actor_username);
  INSERT INTO letter_post_search_fts5(rowid, object_id, content, content_plaintext, actor_username)
  VALUES (new.rowid, new.object_id, new.content, new.content_plaintext, new.actor_username);
END;
CREATE TRIGGER objects_search_insert AFTER INSERT ON objects
WHEN NEW.object_type = 'Note' AND NEW.visibility = 'public'
BEGIN
  INSERT INTO letter_post_search(object_id, content, content_plaintext, actor_username)
  SELECT NEW.id, NEW.content, NEW.content_plaintext, actors.username
  FROM actors WHERE actors.id = NEW.actor_id;
END;
CREATE TRIGGER objects_search_update AFTER UPDATE ON objects
WHEN NEW.object_type = 'Note' AND NEW.visibility = 'public'
BEGIN
  DELETE FROM letter_post_search WHERE object_id = OLD.id;
  INSERT INTO letter_post_search(object_id, content, content_plaintext, actor_username)
  SELECT NEW.id, NEW.content, NEW.content_plaintext, actors.username
  FROM actors WHERE actors.id = NEW.actor_id;
END;
CREATE TRIGGER objects_search_delete AFTER DELETE ON objects
BEGIN
  DELETE FROM letter_post_search WHERE object_id = OLD.id;
END;
CREATE TABLE IF NOT EXISTS "active_storage_blobs" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "key" varchar NOT NULL, "filename" varchar NOT NULL, "content_type" varchar, "metadata" text, "service_name" varchar NOT NULL, "byte_size" bigint NOT NULL, "checksum" varchar, "created_at" datetime(6) NOT NULL);
CREATE UNIQUE INDEX "index_active_storage_blobs_on_key" ON "active_storage_blobs" ("key") /*application='letter'*/;
CREATE TABLE IF NOT EXISTS "active_storage_attachments" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "name" varchar NOT NULL, "record_type" varchar NOT NULL, "record_id" bigint NOT NULL, "blob_id" bigint NOT NULL, "created_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_c3b3935057"
FOREIGN KEY ("blob_id")
  REFERENCES "active_storage_blobs" ("id")
);
CREATE INDEX "index_active_storage_attachments_on_blob_id" ON "active_storage_attachments" ("blob_id") /*application='letter'*/;
CREATE UNIQUE INDEX "index_active_storage_attachments_uniqueness" ON "active_storage_attachments" ("record_type", "record_id", "name", "blob_id") /*application='letter'*/;
CREATE TABLE IF NOT EXISTS "active_storage_variant_records" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "blob_id" bigint NOT NULL, "variation_digest" varchar NOT NULL, CONSTRAINT "fk_rails_993965df05"
FOREIGN KEY ("blob_id")
  REFERENCES "active_storage_blobs" ("id")
);
CREATE UNIQUE INDEX "index_active_storage_variant_records_uniqueness" ON "active_storage_variant_records" ("blob_id", "variation_digest") /*application='letter'*/;
CREATE TABLE IF NOT EXISTS "oauth_applications" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "name" varchar NOT NULL, "uid" varchar NOT NULL, "secret" varchar NOT NULL, "redirect_uri" text NOT NULL, "scopes" varchar DEFAULT '' NOT NULL, "confidential" boolean DEFAULT 1 NOT NULL, "website" text, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE UNIQUE INDEX "index_oauth_applications_on_uid" ON "oauth_applications" ("uid") /*application='letter'*/;
CREATE TABLE IF NOT EXISTS "oauth_access_grants" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "resource_owner_id" integer NOT NULL, "application_id" integer NOT NULL, "token" varchar NOT NULL, "expires_in" integer NOT NULL, "redirect_uri" text NOT NULL, "created_at" datetime(6) NOT NULL, "revoked_at" datetime(6), "scopes" varchar DEFAULT '' NOT NULL, CONSTRAINT "fk_rails_b4b53e07b8"
FOREIGN KEY ("application_id")
  REFERENCES "oauth_applications" ("id")
);
CREATE INDEX "index_oauth_access_grants_on_resource_owner_id" ON "oauth_access_grants" ("resource_owner_id") /*application='letter'*/;
CREATE INDEX "index_oauth_access_grants_on_application_id" ON "oauth_access_grants" ("application_id") /*application='letter'*/;
CREATE UNIQUE INDEX "index_oauth_access_grants_on_token" ON "oauth_access_grants" ("token") /*application='letter'*/;
CREATE TABLE IF NOT EXISTS "oauth_access_tokens" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "resource_owner_id" integer, "application_id" integer NOT NULL, "token" varchar NOT NULL, "refresh_token" varchar, "expires_in" integer, "revoked_at" datetime(6), "created_at" datetime(6) NOT NULL, "scopes" varchar, "previous_refresh_token" varchar DEFAULT '' NOT NULL, CONSTRAINT "fk_rails_732cb83ab7"
FOREIGN KEY ("application_id")
  REFERENCES "oauth_applications" ("id")
);
CREATE INDEX "index_oauth_access_tokens_on_resource_owner_id" ON "oauth_access_tokens" ("resource_owner_id") /*application='letter'*/;
CREATE INDEX "index_oauth_access_tokens_on_application_id" ON "oauth_access_tokens" ("application_id") /*application='letter'*/;
CREATE UNIQUE INDEX "index_oauth_access_tokens_on_token" ON "oauth_access_tokens" ("token") /*application='letter'*/;
CREATE UNIQUE INDEX "index_oauth_access_tokens_on_refresh_token" ON "oauth_access_tokens" ("refresh_token") /*application='letter'*/;
CREATE TABLE IF NOT EXISTS "solid_queue_jobs" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "queue_name" varchar NOT NULL, "class_name" varchar NOT NULL, "arguments" text, "priority" integer DEFAULT 0 NOT NULL, "active_job_id" varchar, "scheduled_at" datetime(6), "finished_at" datetime(6), "concurrency_key" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE INDEX "index_solid_queue_jobs_for_polling" ON "solid_queue_jobs" ("queue_name") /*application='letter'*/;
CREATE UNIQUE INDEX "index_solid_queue_jobs_on_active_job_id" ON "solid_queue_jobs" ("active_job_id") /*application='letter'*/;
CREATE INDEX "index_solid_queue_jobs_on_finished_at" ON "solid_queue_jobs" ("finished_at") /*application='letter'*/;
CREATE INDEX "index_solid_queue_jobs_for_filtering" ON "solid_queue_jobs" ("class_name", "finished_at") /*application='letter'*/;
CREATE INDEX "index_solid_queue_jobs_for_alerting" ON "solid_queue_jobs" ("scheduled_at", "finished_at") /*application='letter'*/;
CREATE TABLE IF NOT EXISTS "solid_queue_scheduled_executions" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "job_id" integer NOT NULL, "queue_name" varchar NOT NULL, "priority" integer DEFAULT 0 NOT NULL, "scheduled_at" datetime(6) NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_c4316f352d"
FOREIGN KEY ("job_id")
  REFERENCES "solid_queue_jobs" ("id")
);
CREATE INDEX "index_solid_queue_dispatch_all" ON "solid_queue_scheduled_executions" ("scheduled_at", "priority", "job_id") /*application='letter'*/;
CREATE TABLE IF NOT EXISTS "solid_queue_ready_executions" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "job_id" integer NOT NULL, "queue_name" varchar NOT NULL, "priority" integer DEFAULT 0 NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_81fcbd66af"
FOREIGN KEY ("job_id")
  REFERENCES "solid_queue_jobs" ("id")
);
CREATE INDEX "index_solid_queue_poll_all" ON "solid_queue_ready_executions" ("priority", "job_id") /*application='letter'*/;
CREATE INDEX "index_solid_queue_poll_by_queue" ON "solid_queue_ready_executions" ("queue_name", "priority", "job_id") /*application='letter'*/;
CREATE TABLE IF NOT EXISTS "solid_queue_claimed_executions" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "job_id" integer NOT NULL, "process_id" bigint, "created_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_9cfe4d4944"
FOREIGN KEY ("job_id")
  REFERENCES "solid_queue_jobs" ("id")
);
CREATE INDEX "index_solid_queue_claimed_executions_on_process_id_and_job_id" ON "solid_queue_claimed_executions" ("process_id", "job_id") /*application='letter'*/;
CREATE TABLE IF NOT EXISTS "solid_queue_blocked_executions" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "job_id" integer NOT NULL, "queue_name" varchar NOT NULL, "priority" integer DEFAULT 0 NOT NULL, "concurrency_key" varchar NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_4cd34e2228"
FOREIGN KEY ("job_id")
  REFERENCES "solid_queue_jobs" ("id")
);
CREATE INDEX "index_solid_queue_blocked_executions" ON "solid_queue_blocked_executions" ("concurrency_key", "priority", "job_id") /*application='letter'*/;
CREATE TABLE IF NOT EXISTS "solid_queue_failed_executions" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "job_id" integer NOT NULL, "error" text, "created_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_39bbc7a631"
FOREIGN KEY ("job_id")
  REFERENCES "solid_queue_jobs" ("id")
);
CREATE INDEX "index_solid_queue_failed_executions" ON "solid_queue_failed_executions" ("job_id") /*application='letter'*/;
CREATE TABLE IF NOT EXISTS "solid_queue_pauses" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "queue_name" varchar NOT NULL, "created_at" datetime(6) NOT NULL);
CREATE UNIQUE INDEX "index_solid_queue_pauses_on_queue_name" ON "solid_queue_pauses" ("queue_name") /*application='letter'*/;
CREATE TABLE IF NOT EXISTS "solid_queue_processes" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "kind" varchar NOT NULL, "name" varchar, "last_heartbeat_at" datetime(6) NOT NULL, "supervisor_id" bigint, "pid" integer NOT NULL, "hostname" varchar, "metadata" text, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE INDEX "index_solid_queue_processes_on_last_heartbeat_at" ON "solid_queue_processes" ("last_heartbeat_at") /*application='letter'*/;
CREATE TABLE IF NOT EXISTS "solid_queue_semaphores" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "key" varchar NOT NULL, "value" integer DEFAULT 1 NOT NULL, "expires_at" datetime(6) NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT chk_rails_solid_queue_semaphores_on_value CHECK (value > 0));
CREATE UNIQUE INDEX "index_solid_queue_semaphores_on_key" ON "solid_queue_semaphores" ("key") /*application='letter'*/;
CREATE INDEX "index_solid_queue_semaphores_on_expires_at" ON "solid_queue_semaphores" ("expires_at") /*application='letter'*/;
CREATE TABLE IF NOT EXISTS "notifications" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "account_id" integer NOT NULL, "from_account_id" integer NOT NULL, "activity_type" varchar NOT NULL, "activity_id" varchar NOT NULL, "notification_type" varchar NOT NULL, "read" boolean DEFAULT 0 NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_1c0a19e3ee"
FOREIGN KEY ("account_id")
  REFERENCES "actors" ("id")
, CONSTRAINT "fk_rails_a9df2835a1"
FOREIGN KEY ("from_account_id")
  REFERENCES "actors" ("id")
);
CREATE INDEX "index_notifications_on_account_id" ON "notifications" ("account_id") /*application='letter'*/;
CREATE INDEX "index_notifications_on_from_account_id" ON "notifications" ("from_account_id") /*application='letter'*/;
CREATE INDEX "index_notifications_on_account_id_and_created_at" ON "notifications" ("account_id", "created_at") /*application='letter'*/;
CREATE INDEX "index_notifications_on_account_id_and_notification_type" ON "notifications" ("account_id", "notification_type") /*application='letter'*/;
CREATE INDEX "index_notifications_on_account_id_and_read" ON "notifications" ("account_id", "read") /*application='letter'*/;
INSERT INTO "schema_migrations" (version) VALUES
('20250617000011'),
('20250617000010'),
('20250617000009'),
('20250617000008'),
('20250617000007'),
('20250617000006'),
('20250617000005'),
('20250617000004'),
('20250617000003'),
('20250617000002'),
('20250617000001');

