# frozen_string_literal: true

class SharedInboxesController < ApplicationController
  include ActivityPubVerification
  include ActivityPubHandlers
  include ActivityPubObjectHandlers
  include ActivityPubCreateHandlers

  # CSRFトークン無効化（外部からのPOST）
  skip_before_action :verify_authenticity_token

  # Content-Type検証
  before_action :verify_content_type
  before_action :parse_activity_json
  before_action :verify_http_signature
  before_action :find_or_create_sender
  before_action :check_if_relay_activity

  def create
    if @is_relay_activity
      handle_relay_activity
    else
      handle_regular_activity
    end
  rescue StandardError => e
    handle_general_error(e)
  end

  private

  def check_if_relay_activity
    @is_relay_activity = false

    # 送信者がリレーかどうかをチェック
    return unless @sender

    # リレーアクターのURIとマッチするリレーを探す（accepted・pending両方を対象）
    relay = (Relay.accepted.to_a + Relay.pending.to_a).find do |r|
      r.actor_uri == @sender.ap_id
    end

    @is_relay_activity = !relay.nil?
    @relay = relay if @is_relay_activity
  end

  def handle_relay_activity
    case @activity['type']
    when 'Accept'
      handle_relay_accept
    when 'Reject'
      handle_relay_reject
    when 'Announce'
      handle_relay_announce
    when 'Undo'
      handle_relay_undo
    else
      Rails.logger.warn "⚠️ Unsupported relay activity type: #{@activity['type']}"
      head :accepted
    end
  end

  def handle_regular_activity
    # 通常のActivityPub活動処理（既存のInboxControllerと同様）
    case @activity['type']
    when 'Create'
      handle_create_activity
    when 'Update'
      handle_update_activity
    when 'Delete'
      handle_delete_activity
    when 'Announce'
      handle_announce_activity
    when 'Like'
      handle_like_activity
    when 'Undo'
      handle_undo_activity
    else
      Rails.logger.warn "⚠️ Unsupported activity type: #{@activity['type']}"
      head :accepted
    end
  end

  def handle_relay_accept
    return head :bad_request unless @relay

    # Follow要求が受け入れられた
    if @activity['object'] == @relay.follow_activity_id
      @relay.update!(
        state: 'accepted',
        last_error: nil,
        delivery_attempts: 0
      )
    end

    head :accepted
  end

  def handle_relay_reject
    return head :bad_request unless @relay

    # Follow要求が拒否された
    if @activity['object'] == @relay.follow_activity_id
      @relay.update!(
        state: 'rejected',
        last_error: 'Follow request rejected by relay',
        follow_activity_id: nil,
        followed_at: nil
      )
    end

    head :accepted
  end

  def handle_relay_announce
    return head :bad_request unless @relay

    # リレーからのAnnounce（投稿の再配信）を処理
    object_id = @activity['object']
    return head :bad_request unless object_id.is_a?(String)

    # 既に処理済みかチェック
    existing_object = ActivityPubObject.find_by(ap_id: object_id)
    return head :accepted if existing_object

    # 元の投稿を取得して処理
    RelayAnnounceProcessorJob.perform_later(@activity, @relay.id)

    head :accepted
  end

  def handle_relay_undo
    return head :bad_request unless @relay

    # リレーからのUndo処理（通常はフォロー解除）
    head :accepted
  end

  def handle_general_error(error)
    Rails.logger.error "Shared inbox processing error: #{error.message}"
    Rails.logger.error error.backtrace.first(5).join("\n")
    head :internal_server_error
  end
end
