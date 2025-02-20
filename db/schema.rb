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

ActiveRecord::Schema[7.1].define(version: 2025_02_19_195255) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "ancestors", force: :cascade do |t|
    t.bigint "horse_id", null: false
    t.string "name"
    t.string "breed"
    t.string "breeder"
    t.string "relation_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["horse_id", "relation_type"], name: "index_ancestors_on_horse_id_and_relation_type", unique: true
    t.index ["horse_id"], name: "index_ancestors_on_horse_id"
  end

  create_table "horses", force: :cascade do |t|
    t.string "name"
    t.integer "age"
    t.text "description"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "height_cm", precision: 4, scale: 2
    t.string "gender"
    t.string "color"
    t.string "training_level"
    t.boolean "piroplasmosis"
    t.string "breed"
    t.string "breeder"
    t.index ["user_id"], name: "index_horses_on_user_id"
  end

  create_table "horses_users", id: false, force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "horse_id", null: false
    t.index ["horse_id"], name: "index_horses_users_on_horse_id"
    t.index ["user_id"], name: "index_horses_users_on_user_id"
  end

  create_table "logs", force: :cascade do |t|
    t.string "action"
    t.string "horse_name"
    t.string "recipient"
    t.integer "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "photos", force: :cascade do |t|
    t.bigint "horse_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["horse_id"], name: "index_photos_on_horse_id"
  end

  create_table "plans", force: :cascade do |t|
    t.string "name"
    t.decimal "price"
    t.integer "max_horses"
    t.integer "max_transfers"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "shared_links", force: :cascade do |t|
    t.string "token", null: false
    t.bigint "horse_id", null: false
    t.datetime "expires_at"
    t.string "status", default: "active"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "used_at"
    t.integer "user_id"
    t.integer "shared_by"
    t.index ["horse_id"], name: "index_shared_links_on_horse_id"
    t.index ["token"], name: "index_shared_links_on_token", unique: true
  end

  create_table "transfer_histories", force: :cascade do |t|
    t.bigint "horse_id", null: false
    t.bigint "from_user_id", null: false
    t.bigint "to_user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["from_user_id"], name: "index_transfer_histories_on_from_user_id"
    t.index ["horse_id"], name: "index_transfer_histories_on_horse_id"
    t.index ["to_user_id"], name: "index_transfer_histories_on_to_user_id"
  end

  create_table "user_horses", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "horse_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "shared_by"
    t.index ["horse_id"], name: "index_user_horses_on_horse_id"
    t.index ["user_id"], name: "index_user_horses_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "first_name"
    t.string "last_name"
    t.date "birthdate"
    t.string "phone_number"
    t.string "country"
    t.string "gender"
    t.boolean "admin"
    t.string "plan", default: "free"
    t.integer "used_horses", default: 0
    t.integer "used_transfers", default: 0
    t.datetime "subscription_end"
    t.integer "used_shares", default: 0
    t.string "stripe_subscription_id"
    t.string "stripe_customer_id"
    t.string "stripe_default_payment_method"
    t.integer "max_horses"
    t.integer "max_shares"
    t.boolean "subscription_canceled", default: false, null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["stripe_customer_id"], name: "index_users_on_stripe_customer_id", unique: true
    t.index ["stripe_default_payment_method"], name: "index_users_on_stripe_default_payment_method", unique: true
    t.index ["stripe_subscription_id"], name: "index_users_on_stripe_subscription_id", unique: true
  end

  create_table "videos", force: :cascade do |t|
    t.bigint "horse_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["horse_id"], name: "index_videos_on_horse_id"
  end

  create_table "xrays", force: :cascade do |t|
    t.bigint "horse_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["horse_id"], name: "index_xrays_on_horse_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "ancestors", "horses"
  add_foreign_key "horses", "users"
  add_foreign_key "horses_users", "horses"
  add_foreign_key "horses_users", "users"
  add_foreign_key "photos", "horses"
  add_foreign_key "shared_links", "horses"
  add_foreign_key "shared_links", "users"
  add_foreign_key "transfer_histories", "horses"
  add_foreign_key "transfer_histories", "users", column: "from_user_id"
  add_foreign_key "transfer_histories", "users", column: "to_user_id"
  add_foreign_key "user_horses", "horses"
  add_foreign_key "user_horses", "users"
  add_foreign_key "user_horses", "users", column: "shared_by"
  add_foreign_key "videos", "horses"
  add_foreign_key "xrays", "horses"
end
