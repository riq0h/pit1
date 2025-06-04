# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_06_04_054724) do
  create_table "activities", force: :cascade do |t|
    t.string "ap_id", null: false
    t.string "activity_type", null: false
    t.integer "actor_id", null: false
    t.integer "object_id"
    t.string "target_ap_id"
    t.json "raw_data"
    t.datetime "published_at"
    t.boolean "local", default: false
    t.boolean "processed", default: false
    t.datetime "processed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["activity_type"], name: "index_activities_on_activity_type"
    t.index ["actor_id", "published_at"], name: "index_activities_on_actor_id_and_published_at"
    t.index ["actor_id"], name: "index_activities_on_actor_id"
    t.index ["ap_id"], name: "index_activities_on_ap_id", unique: true
    t.index ["local"], name: "index_activities_on_local"
    t.index ["object_id"], name: "index_activities_on_object_id"
    t.index ["processed"], name: "index_activities_on_processed"
    t.index ["target_ap_id"], name: "index_activities_on_target_ap_id"
  end

  create_table "actors", force: :cascade do |t|
    t.string "username", null: false
    t.string "domain"
    t.string "ap_id", null: false
    t.string "display_name"
    t.text "summary"
    t.string "avatar_url"
    t.string "header_url"
    t.string "inbox_url", null: false
    t.string "outbox_url", null: false
    t.string "followers_url"
    t.string "following_url"
    t.string "shared_inbox_url"
    t.text "public_key", null: false
    t.text "private_key"
    t.integer "followers_count", default: 0
    t.integer "following_count", default: 0
    t.integer "posts_count", default: 0
    t.boolean "local", default: false, null: false
    t.boolean "suspended", default: false
    t.boolean "locked", default: false
    t.datetime "last_fetched_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ap_id"], name: "index_actors_on_ap_id", unique: true
    t.index ["domain"], name: "index_actors_on_domain"
    t.index ["inbox_url"], name: "index_actors_on_inbox_url"
    t.index ["local"], name: "index_actors_on_local"
    t.index ["shared_inbox_url"], name: "index_actors_on_shared_inbox_url"
    t.index ["username", "domain"], name: "index_actors_on_username_and_domain", unique: true
  end

  create_table "follows", force: :cascade do |t|
    t.integer "actor_id", null: false
    t.integer "target_actor_id", null: false
    t.string "ap_id", null: false
    t.string "follow_activity_ap_id"
    t.string "accept_activity_ap_id"
    t.boolean "accepted", default: false
    t.datetime "accepted_at"
    t.boolean "blocked", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["accepted"], name: "index_follows_on_accepted"
    t.index ["actor_id", "target_actor_id"], name: "index_follows_on_actor_id_and_target_actor_id", unique: true
    t.index ["actor_id"], name: "index_follows_on_actor_id"
    t.index ["ap_id"], name: "index_follows_on_ap_id", unique: true
    t.index ["follow_activity_ap_id"], name: "index_follows_on_follow_activity_ap_id"
    t.index ["target_actor_id"], name: "index_follows_on_target_actor_id"
  end

  create_table "media_attachments", force: :cascade do |t|
    t.integer "object_id", null: false
    t.integer "actor_id", null: false
    t.string "file_name"
    t.string "content_type"
    t.bigint "file_size"
    t.string "storage_path"
    t.string "remote_url"
    t.integer "width"
    t.integer "height"
    t.string "blurhash"
    t.text "description"
    t.string "attachment_type", default: "image"
    t.boolean "processed", default: false
    t.json "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id"], name: "index_media_attachments_on_actor_id"
    t.index ["attachment_type"], name: "index_media_attachments_on_attachment_type"
    t.index ["blurhash"], name: "index_media_attachments_on_blurhash"
    t.index ["object_id"], name: "index_media_attachments_on_object_id"
    t.index ["processed"], name: "index_media_attachments_on_processed"
  end

  create_table "objects", force: :cascade do |t|
    t.string "ap_id", null: false
    t.string "object_type", null: false
    t.integer "actor_id", null: false
    t.string "in_reply_to_ap_id"
    t.string "conversation_ap_id"
    t.text "content"
    t.text "content_plaintext"
    t.string "summary"
    t.string "url"
    t.string "language", default: "ja"
    t.string "media_type"
    t.string "blurhash"
    t.integer "width"
    t.integer "height"
    t.boolean "sensitive", default: false
    t.string "visibility", default: "public"
    t.json "raw_data"
    t.datetime "published_at"
    t.boolean "local", default: false
    t.integer "replies_count", default: 0
    t.integer "reblogs_count", default: 0
    t.integer "favourites_count", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id", "published_at"], name: "index_objects_on_actor_id_and_published_at"
    t.index ["actor_id"], name: "index_objects_on_actor_id"
    t.index ["ap_id"], name: "index_objects_on_ap_id", unique: true
    t.index ["conversation_ap_id"], name: "index_objects_on_conversation_ap_id"
    t.index ["in_reply_to_ap_id"], name: "index_objects_on_in_reply_to_ap_id"
    t.index ["local"], name: "index_objects_on_local"
    t.index ["object_type"], name: "index_objects_on_object_type"
    t.index ["published_at"], name: "index_objects_on_published_at"
    t.index ["visibility"], name: "index_objects_on_visibility"
  end

  create_table "user_limits", force: :cascade do |t|
    t.integer "current_users", default: 0
    t.integer "max_users", default: 2
    t.integer "max_post_length", default: 9999
    t.boolean "registration_open", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "activities", "actors"
  add_foreign_key "activities", "objects"
  add_foreign_key "follows", "actors"
  add_foreign_key "follows", "actors", column: "target_actor_id"
  add_foreign_key "media_attachments", "actors"
  add_foreign_key "media_attachments", "objects"
  add_foreign_key "objects", "actors"

  # Virtual tables defined in this database.
  # Note that virtual tables may not work with other database engines. Be careful if changing database.
