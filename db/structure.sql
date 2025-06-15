CREATE TABLE IF NOT EXISTS "ar_internal_metadata" ("key" varchar NOT NULL PRIMARY KEY, "value" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE TABLE IF NOT EXISTS "schema_migrations" ("version" varchar NOT NULL PRIMARY KEY);
CREATE TABLE IF NOT EXISTS "actors" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "username" varchar(20) NOT NULL, "domain" varchar(255), "display_name" varchar(100), "summary" text, "ap_id" varchar NOT NULL, "inbox_url" varchar NOT NULL, "outbox_url" varchar NOT NULL, "followers_url" varchar NOT NULL, "following_url" varchar NOT NULL, "public_key" text NOT NULL, "private_key" text, "avatar_url" varchar, "header_url" varchar, "local" boolean DEFAULT 0 NOT NULL, "locked" boolean DEFAULT 0 NOT NULL, "bot" boolean DEFAULT 0 NOT NULL, "suspended" boolean DEFAULT 0 NOT NULL, "followers_count" integer DEFAULT 0 NOT NULL, "following_count" integer DEFAULT 0 NOT NULL, "posts_count" integer DEFAULT 0 NOT NULL, "raw_data" json, "last_fetched_at" datetime(6), "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "actor_type" varchar DEFAULT 'Person', "discoverable" boolean DEFAULT 1, "manually_approves_followers" boolean DEFAULT 0, "featured_url" varchar, "icon_url" varchar, "password_digest" varchar /*application='Letter'*/);
CREATE UNIQUE INDEX "index_actors_on_ap_id" ON "actors" ("ap_id") /*application='Letter'*/;
CREATE UNIQUE INDEX "index_actors_on_username_and_domain" ON "actors" ("username", "domain") /*application='Letter'*/;
CREATE INDEX "index_actors_on_domain" ON "actors" ("domain") /*application='Letter'*/;
CREATE INDEX "index_actors_on_local" ON "actors" ("local") /*application='Letter'*/;
CREATE INDEX "index_actors_on_suspended" ON "actors" ("suspended") /*application='Letter'*/;
CREATE INDEX "index_actors_on_actor_type" ON "actors" ("actor_type") /*application='Letter'*/;
CREATE INDEX "index_actors_on_discoverable" ON "actors" ("discoverable") /*application='Letter'*/;
CREATE INDEX "index_actors_on_manually_approves_followers" ON "actors" ("manually_approves_followers") /*application='Letter'*/;
CREATE TABLE IF NOT EXISTS "user_limits" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "actor_id" integer, "limit_type" varchar(50) NOT NULL, "limit_value" integer NOT NULL, "current_usage" integer DEFAULT 0 NOT NULL, "enabled" boolean DEFAULT 1 NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_1c7d473965"
FOREIGN KEY ("actor_id")
  REFERENCES "actors" ("id")
);
CREATE INDEX "index_user_limits_on_actor_id" ON "user_limits" ("actor_id") /*application='Letter'*/;
CREATE UNIQUE INDEX "index_user_limits_on_actor_id_and_limit_type" ON "user_limits" ("actor_id", "limit_type") /*application='Letter'*/;
CREATE INDEX "index_user_limits_on_limit_type" ON "user_limits" ("limit_type") /*application='Letter'*/;
CREATE INDEX "index_user_limits_on_enabled" ON "user_limits" ("enabled") /*application='Letter'*/;
CREATE INDEX "index_user_limits_on_system_limits" ON "user_limits" ("limit_type") WHERE actor_id IS NULL /*application='Letter'*/;
CREATE TABLE IF NOT EXISTS "activities" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "ap_id" varchar NOT NULL, "activity_type" varchar NOT NULL, "actor_id" varchar, "object_id" varchar, "target_ap_id" varchar, "raw_data" json, "published_at" datetime(6), "local" boolean DEFAULT 0, "processed" boolean DEFAULT 0, "processed_at" datetime(6), "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "delivered" boolean DEFAULT 0 NOT NULL, "delivered_at" datetime(6), "delivery_attempts" integer DEFAULT 0 NOT NULL, "last_delivery_error" text, CONSTRAINT "fk_rails_5c0136e7dd"
FOREIGN KEY ("actor_id")
  REFERENCES "actors" ("id")
, CONSTRAINT "fk_rails_9cc4ea825d"
FOREIGN KEY ("object_id")
  REFERENCES "objects" ("id")
);
CREATE UNIQUE INDEX "index_activities_on_ap_id" ON "activities" ("ap_id") /*application='Letter'*/;
CREATE INDEX "index_activities_on_actor_id" ON "activities" ("actor_id") /*application='Letter'*/;
CREATE INDEX "index_activities_on_object_id" ON "activities" ("object_id") /*application='Letter'*/;
CREATE INDEX "index_activities_on_activity_type" ON "activities" ("activity_type") /*application='Letter'*/;
CREATE INDEX "index_activities_on_actor_id_and_published_at" ON "activities" ("actor_id", "published_at") /*application='Letter'*/;
CREATE INDEX "index_activities_on_local" ON "activities" ("local") /*application='Letter'*/;
CREATE INDEX "index_activities_on_processed" ON "activities" ("processed") /*application='Letter'*/;
CREATE INDEX "index_activities_on_target_ap_id" ON "activities" ("target_ap_id") /*application='Letter'*/;
CREATE INDEX "index_activities_on_delivered" ON "activities" ("delivered") /*application='Letter'*/;
CREATE INDEX "index_activities_on_delivered_at" ON "activities" ("delivered_at") /*application='Letter'*/;
CREATE INDEX "index_activities_on_local_and_delivered" ON "activities" ("local", "delivered") /*application='Letter'*/;
CREATE TABLE IF NOT EXISTS "follows" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "actor_id" varchar, "target_actor_id" varchar, "ap_id" varchar NOT NULL, "follow_activity_ap_id" varchar, "accept_activity_ap_id" varchar, "accepted" boolean DEFAULT 0, "accepted_at" datetime(6), "blocked" boolean DEFAULT 0, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_66a3328916"
FOREIGN KEY ("actor_id")
  REFERENCES "actors" ("id")
, CONSTRAINT "fk_rails_fd5b071a42"
FOREIGN KEY ("target_actor_id")
  REFERENCES "actors" ("id")
);
CREATE INDEX "index_follows_on_actor_id" ON "follows" ("actor_id") /*application='Letter'*/;
CREATE INDEX "index_follows_on_target_actor_id" ON "follows" ("target_actor_id") /*application='Letter'*/;
CREATE UNIQUE INDEX "index_follows_on_ap_id" ON "follows" ("ap_id") /*application='Letter'*/;
CREATE UNIQUE INDEX "index_follows_on_actor_id_and_target_actor_id" ON "follows" ("actor_id", "target_actor_id") /*application='Letter'*/;
CREATE INDEX "index_follows_on_accepted" ON "follows" ("accepted") /*application='Letter'*/;
CREATE INDEX "index_follows_on_follow_activity_ap_id" ON "follows" ("follow_activity_ap_id") /*application='Letter'*/;
CREATE TABLE IF NOT EXISTS "oauth_applications" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "name" varchar NOT NULL, "uid" varchar NOT NULL, "secret" varchar NOT NULL, "redirect_uri" text NOT NULL, "scopes" varchar DEFAULT '' NOT NULL, "confidential" boolean DEFAULT 1 NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE UNIQUE INDEX "index_oauth_applications_on_uid" ON "oauth_applications" ("uid") /*application='Letter'*/;
CREATE TABLE IF NOT EXISTS "oauth_access_grants" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "resource_owner_id" integer NOT NULL, "application_id" integer NOT NULL, "token" varchar NOT NULL, "expires_in" integer NOT NULL, "redirect_uri" text NOT NULL, "scopes" varchar DEFAULT '' NOT NULL, "created_at" datetime(6) NOT NULL, "revoked_at" datetime(6), CONSTRAINT "fk_rails_b4b53e07b8"
FOREIGN KEY ("application_id")
  REFERENCES "oauth_applications" ("id")
);
CREATE INDEX "index_oauth_access_grants_on_resource_owner_id" ON "oauth_access_grants" ("resource_owner_id") /*application='Letter'*/;
CREATE INDEX "index_oauth_access_grants_on_application_id" ON "oauth_access_grants" ("application_id") /*application='Letter'*/;
CREATE UNIQUE INDEX "index_oauth_access_grants_on_token" ON "oauth_access_grants" ("token") /*application='Letter'*/;
CREATE TABLE IF NOT EXISTS "oauth_access_tokens" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "resource_owner_id" integer, "application_id" integer NOT NULL, "token" varchar NOT NULL, "refresh_token" varchar, "expires_in" integer, "scopes" varchar, "created_at" datetime(6) NOT NULL, "revoked_at" datetime(6), "previous_refresh_token" varchar DEFAULT '' NOT NULL, CONSTRAINT "fk_rails_732cb83ab7"
FOREIGN KEY ("application_id")
  REFERENCES "oauth_applications" ("id")
);
CREATE INDEX "index_oauth_access_tokens_on_resource_owner_id" ON "oauth_access_tokens" ("resource_owner_id") /*application='Letter'*/;
CREATE INDEX "index_oauth_access_tokens_on_application_id" ON "oauth_access_tokens" ("application_id") /*application='Letter'*/;
CREATE UNIQUE INDEX "index_oauth_access_tokens_on_token" ON "oauth_access_tokens" ("token") /*application='Letter'*/;
CREATE UNIQUE INDEX "index_oauth_access_tokens_on_refresh_token" ON "oauth_access_tokens" ("refresh_token") /*application='Letter'*/;
CREATE TABLE IF NOT EXISTS "tags" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "name" varchar NOT NULL, "usages_count" integer DEFAULT 0 NOT NULL, "last_used_at" datetime(6), "trending" boolean DEFAULT 0, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE UNIQUE INDEX "index_tags_on_name" ON "tags" ("name") /*application='Letter'*/;
CREATE INDEX "index_tags_on_usages_count" ON "tags" ("usages_count") /*application='Letter'*/;
CREATE INDEX "index_tags_on_trending" ON "tags" ("trending") /*application='Letter'*/;
CREATE INDEX "index_tags_on_last_used_at" ON "tags" ("last_used_at") /*application='Letter'*/;
CREATE TABLE IF NOT EXISTS "object_tags" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "object_id" varchar, "tag_id" integer NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_8f6810534c"
FOREIGN KEY ("tag_id")
  REFERENCES "tags" ("id")
, CONSTRAINT "fk_rails_11c6375210"
FOREIGN KEY ("object_id")
  REFERENCES "objects" ("id")
);
CREATE INDEX "index_object_tags_on_object_id" ON "object_tags" ("object_id") /*application='Letter'*/;
CREATE INDEX "index_object_tags_on_tag_id" ON "object_tags" ("tag_id") /*application='Letter'*/;
CREATE UNIQUE INDEX "index_object_tags_on_object_id_and_tag_id" ON "object_tags" ("object_id", "tag_id") /*application='Letter'*/;
CREATE TABLE IF NOT EXISTS "favourites" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "actor_id" integer, "object_id" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_868448e3f7"
FOREIGN KEY ("object_id")
  REFERENCES "objects" ("id")
, CONSTRAINT "fk_rails_757549d945"
FOREIGN KEY ("actor_id")
  REFERENCES "actors" ("id")
);
CREATE INDEX "index_favourites_on_actor_id" ON "favourites" ("actor_id") /*application='Letter'*/;
CREATE INDEX "index_favourites_on_object_id" ON "favourites" ("object_id") /*application='Letter'*/;
CREATE UNIQUE INDEX "index_favourites_on_actor_id_and_object_id" ON "favourites" ("actor_id", "object_id") /*application='Letter'*/;
CREATE TABLE IF NOT EXISTS "reblogs" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "actor_id" integer, "object_id" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_f85b673d2b"
FOREIGN KEY ("object_id")
  REFERENCES "objects" ("id")
, CONSTRAINT "fk_rails_16704774d5"
FOREIGN KEY ("actor_id")
  REFERENCES "actors" ("id")
);
CREATE INDEX "index_reblogs_on_actor_id" ON "reblogs" ("actor_id") /*application='Letter'*/;
CREATE INDEX "index_reblogs_on_object_id" ON "reblogs" ("object_id") /*application='Letter'*/;
CREATE UNIQUE INDEX "index_reblogs_on_actor_id_and_object_id" ON "reblogs" ("actor_id", "object_id") /*application='Letter'*/;
CREATE TABLE IF NOT EXISTS "mentions" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "object_id" varchar, "actor_id" integer, "acct" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_227016d488"
FOREIGN KEY ("actor_id")
  REFERENCES "actors" ("id")
, CONSTRAINT "fk_rails_6a4030f320"
FOREIGN KEY ("object_id")
  REFERENCES "objects" ("id")
);
CREATE INDEX "index_mentions_on_object_id" ON "mentions" ("object_id") /*application='Letter'*/;
CREATE INDEX "index_mentions_on_actor_id" ON "mentions" ("actor_id") /*application='Letter'*/;
CREATE UNIQUE INDEX "index_mentions_on_object_id_and_actor_id" ON "mentions" ("object_id", "actor_id") /*application='Letter'*/;
CREATE TABLE IF NOT EXISTS "blocks" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "actor_id" integer, "target_actor_id" integer, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_015885e298"
FOREIGN KEY ("actor_id")
  REFERENCES "actors" ("id")
, CONSTRAINT "fk_rails_5bd836e0fd"
FOREIGN KEY ("target_actor_id")
  REFERENCES "actors" ("id")
);
CREATE INDEX "index_blocks_on_actor_id" ON "blocks" ("actor_id") /*application='Letter'*/;
CREATE INDEX "index_blocks_on_target_actor_id" ON "blocks" ("target_actor_id") /*application='Letter'*/;
CREATE UNIQUE INDEX "index_blocks_on_actor_id_and_target_actor_id" ON "blocks" ("actor_id", "target_actor_id") /*application='Letter'*/;
CREATE TABLE IF NOT EXISTS "mutes" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "actor_id" integer, "target_actor_id" integer, "notifications" boolean DEFAULT 1, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_bcd731dacd"
FOREIGN KEY ("actor_id")
  REFERENCES "actors" ("id")
, CONSTRAINT "fk_rails_caa1aeaa2a"
FOREIGN KEY ("target_actor_id")
  REFERENCES "actors" ("id")
);
CREATE INDEX "index_mutes_on_actor_id" ON "mutes" ("actor_id") /*application='Letter'*/;
CREATE INDEX "index_mutes_on_target_actor_id" ON "mutes" ("target_actor_id") /*application='Letter'*/;
CREATE UNIQUE INDEX "index_mutes_on_actor_id_and_target_actor_id" ON "mutes" ("actor_id", "target_actor_id") /*application='Letter'*/;
CREATE TABLE IF NOT EXISTS "domain_blocks" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "actor_id" integer, "domain" varchar NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_ceda607ae5"
FOREIGN KEY ("actor_id")
  REFERENCES "actors" ("id")
);
CREATE INDEX "index_domain_blocks_on_actor_id" ON "domain_blocks" ("actor_id") /*application='Letter'*/;
CREATE UNIQUE INDEX "index_domain_blocks_on_actor_id_and_domain" ON "domain_blocks" ("actor_id", "domain") /*application='Letter'*/;
CREATE INDEX "index_domain_blocks_on_domain" ON "domain_blocks" ("domain") /*application='Letter'*/;
CREATE TABLE IF NOT EXISTS "solid_queue_jobs" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "queue_name" varchar NOT NULL, "class_name" varchar NOT NULL, "arguments" text, "priority" integer DEFAULT 0 NOT NULL, "active_job_id" varchar, "scheduled_at" datetime(6), "finished_at" datetime(6), "concurrency_key" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE INDEX "index_solid_queue_jobs_on_active_job_id" ON "solid_queue_jobs" ("active_job_id") /*application='Letter'*/;
CREATE INDEX "index_solid_queue_jobs_on_class_name" ON "solid_queue_jobs" ("class_name") /*application='Letter'*/;
CREATE INDEX "index_solid_queue_jobs_on_finished_at" ON "solid_queue_jobs" ("finished_at") /*application='Letter'*/;
CREATE INDEX "index_solid_queue_jobs_for_filtering" ON "solid_queue_jobs" ("queue_name", "finished_at") /*application='Letter'*/;
CREATE INDEX "index_solid_queue_jobs_for_alerting" ON "solid_queue_jobs" ("scheduled_at", "finished_at") /*application='Letter'*/;
CREATE TABLE IF NOT EXISTS "solid_queue_pauses" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "queue_name" varchar NOT NULL, "created_at" datetime(6) NOT NULL);
CREATE UNIQUE INDEX "index_solid_queue_pauses_on_queue_name" ON "solid_queue_pauses" ("queue_name") /*application='Letter'*/;
CREATE TABLE IF NOT EXISTS "solid_queue_processes" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "kind" varchar NOT NULL, "last_heartbeat_at" datetime(6) NOT NULL, "supervisor_id" bigint, "pid" integer NOT NULL, "hostname" varchar, "metadata" text, "created_at" datetime(6) NOT NULL, "name" varchar NOT NULL);
CREATE INDEX "index_solid_queue_processes_on_last_heartbeat_at" ON "solid_queue_processes" ("last_heartbeat_at") /*application='Letter'*/;
CREATE UNIQUE INDEX "index_solid_queue_processes_on_name_and_supervisor_id" ON "solid_queue_processes" ("name", "supervisor_id") /*application='Letter'*/;
CREATE INDEX "index_solid_queue_processes_on_supervisor_id" ON "solid_queue_processes" ("supervisor_id") /*application='Letter'*/;
CREATE TABLE IF NOT EXISTS "solid_queue_recurring_tasks" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "key" varchar NOT NULL, "schedule" varchar NOT NULL, "command" varchar(2048), "class_name" varchar, "arguments" text, "queue_name" varchar, "priority" integer DEFAULT 0, "static" boolean DEFAULT 1 NOT NULL, "description" text, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE UNIQUE INDEX "index_solid_queue_recurring_tasks_on_key" ON "solid_queue_recurring_tasks" ("key") /*application='Letter'*/;
CREATE INDEX "index_solid_queue_recurring_tasks_on_static" ON "solid_queue_recurring_tasks" ("static") /*application='Letter'*/;
CREATE TABLE IF NOT EXISTS "solid_queue_semaphores" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "key" varchar NOT NULL, "value" integer DEFAULT 1 NOT NULL, "expires_at" datetime(6) NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE INDEX "index_solid_queue_semaphores_on_expires_at" ON "solid_queue_semaphores" ("expires_at") /*application='Letter'*/;
CREATE INDEX "index_solid_queue_semaphores_on_key_and_value" ON "solid_queue_semaphores" ("key", "value") /*application='Letter'*/;
CREATE UNIQUE INDEX "index_solid_queue_semaphores_on_key" ON "solid_queue_semaphores" ("key") /*application='Letter'*/;
CREATE TABLE IF NOT EXISTS "solid_queue_blocked_executions" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "job_id" bigint NOT NULL, "queue_name" varchar NOT NULL, "priority" integer DEFAULT 0 NOT NULL, "concurrency_key" varchar NOT NULL, "expires_at" datetime(6) NOT NULL, "created_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_4cd34e2228"
FOREIGN KEY ("job_id")
  REFERENCES "solid_queue_jobs" ("id")
 ON DELETE CASCADE);
CREATE INDEX "index_solid_queue_blocked_executions_for_release" ON "solid_queue_blocked_executions" ("concurrency_key", "priority", "job_id") /*application='Letter'*/;
CREATE INDEX "index_solid_queue_blocked_executions_for_maintenance" ON "solid_queue_blocked_executions" ("expires_at", "concurrency_key") /*application='Letter'*/;
CREATE UNIQUE INDEX "index_solid_queue_blocked_executions_on_job_id" ON "solid_queue_blocked_executions" ("job_id") /*application='Letter'*/;
CREATE TABLE IF NOT EXISTS "solid_queue_claimed_executions" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "job_id" bigint NOT NULL, "process_id" bigint, "created_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_9cfe4d4944"
FOREIGN KEY ("job_id")
  REFERENCES "solid_queue_jobs" ("id")
 ON DELETE CASCADE);
CREATE UNIQUE INDEX "index_solid_queue_claimed_executions_on_job_id" ON "solid_queue_claimed_executions" ("job_id") /*application='Letter'*/;
CREATE INDEX "index_solid_queue_claimed_executions_on_process_id_and_job_id" ON "solid_queue_claimed_executions" ("process_id", "job_id") /*application='Letter'*/;
CREATE TABLE IF NOT EXISTS "solid_queue_failed_executions" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "job_id" bigint NOT NULL, "error" text, "created_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_39bbc7a631"
FOREIGN KEY ("job_id")
  REFERENCES "solid_queue_jobs" ("id")
 ON DELETE CASCADE);
CREATE UNIQUE INDEX "index_solid_queue_failed_executions_on_job_id" ON "solid_queue_failed_executions" ("job_id") /*application='Letter'*/;
CREATE TABLE IF NOT EXISTS "solid_queue_ready_executions" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "job_id" bigint NOT NULL, "queue_name" varchar NOT NULL, "priority" integer DEFAULT 0 NOT NULL, "created_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_81fcbd66af"
FOREIGN KEY ("job_id")
  REFERENCES "solid_queue_jobs" ("id")
 ON DELETE CASCADE);
CREATE UNIQUE INDEX "index_solid_queue_ready_executions_on_job_id" ON "solid_queue_ready_executions" ("job_id") /*application='Letter'*/;
CREATE INDEX "index_solid_queue_poll_all" ON "solid_queue_ready_executions" ("priority", "job_id") /*application='Letter'*/;
CREATE INDEX "index_solid_queue_poll_by_queue" ON "solid_queue_ready_executions" ("queue_name", "priority", "job_id") /*application='Letter'*/;
CREATE TABLE IF NOT EXISTS "solid_queue_recurring_executions" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "job_id" bigint NOT NULL, "task_key" varchar NOT NULL, "run_at" datetime(6) NOT NULL, "created_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_318a5533ed"
FOREIGN KEY ("job_id")
  REFERENCES "solid_queue_jobs" ("id")
 ON DELETE CASCADE);
CREATE UNIQUE INDEX "index_solid_queue_recurring_executions_on_job_id" ON "solid_queue_recurring_executions" ("job_id") /*application='Letter'*/;
CREATE UNIQUE INDEX "index_solid_queue_recurring_executions_on_task_key_and_run_at" ON "solid_queue_recurring_executions" ("task_key", "run_at") /*application='Letter'*/;
CREATE TABLE IF NOT EXISTS "solid_queue_scheduled_executions" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "job_id" bigint NOT NULL, "queue_name" varchar NOT NULL, "priority" integer DEFAULT 0 NOT NULL, "scheduled_at" datetime(6) NOT NULL, "created_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_c4316f352d"
FOREIGN KEY ("job_id")
  REFERENCES "solid_queue_jobs" ("id")
 ON DELETE CASCADE);
CREATE UNIQUE INDEX "index_solid_queue_scheduled_executions_on_job_id" ON "solid_queue_scheduled_executions" ("job_id") /*application='Letter'*/;
CREATE INDEX "index_solid_queue_dispatch_all" ON "solid_queue_scheduled_executions" ("scheduled_at", "priority", "job_id") /*application='Letter'*/;
CREATE TABLE IF NOT EXISTS "media_attachments" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "object_id" varchar, "actor_id" varchar, "file_name" varchar, "content_type" varchar, "file_size" bigint, "storage_path" varchar, "remote_url" varchar, "width" integer, "height" integer, "blurhash" varchar, "description" text, "media_type" varchar DEFAULT 'image', "processed" boolean DEFAULT 0, "metadata" json, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_6612e6f1ee"
FOREIGN KEY ("actor_id")
  REFERENCES "actors" ("id")
, CONSTRAINT "fk_rails_7631462b85"
FOREIGN KEY ("object_id")
  REFERENCES "objects" ("id")
);
CREATE INDEX "index_media_attachments_on_object_id" ON "media_attachments" ("object_id") /*application='Letter'*/;
CREATE INDEX "index_media_attachments_on_actor_id" ON "media_attachments" ("actor_id") /*application='Letter'*/;
CREATE INDEX "index_media_attachments_on_processed" ON "media_attachments" ("processed") /*application='Letter'*/;
CREATE INDEX "index_media_attachments_on_blurhash" ON "media_attachments" ("blurhash") /*application='Letter'*/;
CREATE INDEX "index_media_attachments_on_media_type" ON "media_attachments" ("media_type") /*application='Letter'*/;
CREATE TABLE IF NOT EXISTS "conversations" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "last_status_id" integer, "unread" boolean DEFAULT 0 NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE INDEX "index_conversations_on_last_status_id" ON "conversations" ("last_status_id") /*application='Letter'*/;
CREATE INDEX "index_conversations_on_unread" ON "conversations" ("unread") /*application='Letter'*/;
CREATE TABLE IF NOT EXISTS "conversation_participants" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "conversation_id" integer NOT NULL, "actor_id" integer NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_d4fdd4cae0"
FOREIGN KEY ("conversation_id")
  REFERENCES "conversations" ("id")
, CONSTRAINT "fk_rails_883f0f1aba"
FOREIGN KEY ("actor_id")
  REFERENCES "actors" ("id")
);
CREATE INDEX "index_conversation_participants_on_conversation_id" ON "conversation_participants" ("conversation_id") /*application='Letter'*/;
CREATE INDEX "index_conversation_participants_on_actor_id" ON "conversation_participants" ("actor_id") /*application='Letter'*/;
CREATE UNIQUE INDEX "index_conversation_participants_unique" ON "conversation_participants" ("conversation_id", "actor_id") /*application='Letter'*/;
CREATE TABLE IF NOT EXISTS "objects" ("id" varchar NOT NULL PRIMARY KEY, "ap_id" varchar NOT NULL, "object_type" varchar DEFAULT 'Note' NOT NULL, "actor_id" integer NOT NULL, "content" text, "content_plaintext" text, "summary" text, "url" varchar, "language" varchar DEFAULT 'ja', "in_reply_to_ap_id" varchar, "conversation_ap_id" varchar, "media_type" varchar, "blurhash" varchar, "width" integer, "height" integer, "sensitive" boolean DEFAULT 0, "visibility" varchar DEFAULT 'public', "raw_data" json, "published_at" datetime(6), "local" boolean DEFAULT 0, "replies_count" integer DEFAULT 0, "reblogs_count" integer DEFAULT 0, "favourites_count" integer DEFAULT 0, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "conversation_id" integer, CONSTRAINT "fk_rails_1377a551fa"
FOREIGN KEY ("actor_id")
  REFERENCES "actors" ("id")
, CONSTRAINT "fk_rails_eb0aea9dca"
FOREIGN KEY ("conversation_id")
  REFERENCES "conversations" ("id")
);
CREATE INDEX "index_objects_on_actor_id" ON "objects" ("actor_id") /*application='Letter'*/;
CREATE UNIQUE INDEX "index_objects_on_ap_id" ON "objects" ("ap_id") /*application='Letter'*/;
CREATE INDEX "index_objects_on_object_type" ON "objects" ("object_type") /*application='Letter'*/;
CREATE INDEX "index_objects_on_published_at" ON "objects" ("published_at") /*application='Letter'*/;
CREATE INDEX "index_objects_on_visibility" ON "objects" ("visibility") /*application='Letter'*/;
CREATE INDEX "index_objects_on_local" ON "objects" ("local") /*application='Letter'*/;
CREATE INDEX "index_objects_on_in_reply_to_ap_id" ON "objects" ("in_reply_to_ap_id") /*application='Letter'*/;
CREATE INDEX "index_objects_on_conversation_ap_id" ON "objects" ("conversation_ap_id") /*application='Letter'*/;
CREATE INDEX "index_objects_on_conversation_id" ON "objects" ("conversation_id") /*application='Letter'*/;
CREATE VIRTUAL TABLE ap_object_search USING fts5(
        object_id UNINDEXED,
        content_plaintext,
        summary,
        tokenize='porter unicode61'
      )
/* ap_object_search(object_id,content_plaintext,summary) */;
CREATE TABLE IF NOT EXISTS 'ap_object_search_data'(id INTEGER PRIMARY KEY, block BLOB);
CREATE TABLE IF NOT EXISTS 'ap_object_search_idx'(segid, term, pgno, PRIMARY KEY(segid, term)) WITHOUT ROWID;
CREATE TABLE IF NOT EXISTS 'ap_object_search_content'(id INTEGER PRIMARY KEY, c0, c1, c2);
CREATE TABLE IF NOT EXISTS 'ap_object_search_docsize'(id INTEGER PRIMARY KEY, sz BLOB);
CREATE TABLE IF NOT EXISTS 'ap_object_search_config'(k PRIMARY KEY, v) WITHOUT ROWID;
CREATE TRIGGER ap_object_search_insert
      AFTER INSERT ON objects
      WHEN new.object_type = 'Note'
      BEGIN
        INSERT INTO ap_object_search(object_id, content_plaintext, summary)
        VALUES (new.id, COALESCE(new.content_plaintext, ''), COALESCE(new.summary, ''));
      END;
CREATE TRIGGER ap_object_search_delete
      AFTER DELETE ON objects
      WHEN old.object_type = 'Note'
      BEGIN
        DELETE FROM ap_object_search WHERE object_id = old.id;
      END;
CREATE TRIGGER ap_object_search_update
      AFTER UPDATE ON objects
      WHEN new.object_type = 'Note'
      BEGIN
        DELETE FROM ap_object_search WHERE object_id = old.id;
        INSERT INTO ap_object_search(object_id, content_plaintext, summary)
        VALUES (new.id, COALESCE(new.content_plaintext, ''), COALESCE(new.summary, ''));
      END;
INSERT INTO "schema_migrations" (version) VALUES
('20250615000001'),
('20250614231407'),
('20250614230829'),
('20250614230821'),
('20250614113541'),
('20250614074817'),
('20250613125130'),
('20250613124359'),
('20250613122503'),
('20250613043627'),
('20250613043207'),
('20250613043143'),
('20250613042612'),
('20250613042552'),
('20250613042426'),
('20250613041713'),
('20250613041405'),
('20250612234927'),
('20250612050913'),
('20250609134538'),
('20250609133823'),
('20250609133428'),
('20250609124950'),
('20250609073837'),
('20250609072600'),
('20250604054724'),
('20250604054719'),
('20250604054712'),
('20250604054704'),
('20250604054655'),
('20250604054234');

