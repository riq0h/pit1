# frozen_string_literal: true

module StatusCreationHandler
  extend ActiveSupport::Concern

  private

  def build_status_object
    transformed_params = status_params.to_h.symbolize_keys
    transformed_params = process_reply_to_id(transformed_params)

    @status = current_user.objects.build(transformed_params.merge(
                                           object_type: 'Note',
                                           local: true,
                                           published_at: Time.current
                                         ))

    generate_ap_id_for_status
    @status
  end

  def attach_media_to_status
    return unless @media_ids&.any?

    media_attachments = MediaAttachment.where(id: @media_ids, account: current_user)

    if media_attachments.count != @media_ids.count
      missing_ids = @media_ids - media_attachments.pluck(:id)
      Rails.logger.warn "Missing media attachments: #{missing_ids}"
      return render_validation_failed("メディアファイルが見つかりません: #{missing_ids}")
    end

    # メディアタイプの混在チェック
    media_types = media_attachments.pluck(:file_content_type).map { |ct| ct.split('/').first }.uniq
    return render_validation_failed('画像と動画を同時に添付することはできません') if media_types.length > 1

    # 最大枚数チェック
    max_attachments = media_types.first == 'video' ? 1 : 4
    return render_validation_failed("添付できるファイル数を超えています（最大#{max_attachments}個）") if media_attachments.count > max_attachments

    @status.media_attachments = media_attachments
    true
  end

  def process_reply_to_id(transformed_params)
    return transformed_params unless transformed_params[:in_reply_to_id]

    reply_to = ActivityPubObject.find_by(id: transformed_params[:in_reply_to_id])
    if reply_to
      transformed_params[:in_reply_to_ap_id] = reply_to.ap_id
      transformed_params[:visibility] = calculate_reply_visibility(reply_to)

      # 返信先の作者を自動的にメンションに追加
      reply_author = reply_to.actor
      transformed_params[:content] = "@#{reply_author.username} #{transformed_params[:content]}" if reply_author != current_user
    else
      transformed_params[:in_reply_to_ap_id] = nil
    end

    transformed_params.except(:in_reply_to_id)
  end

  def calculate_reply_visibility(reply_to)
    case reply_to.visibility
    when 'public', 'unlisted'
      params[:visibility] || 'public'
    when 'private'
      'private'
    when 'direct'
      'direct'
    else
      'public'
    end
  end

  def handle_direct_message_conversation
    return unless @status.visibility == 'direct'

    # ダイレクトメッセージの場合、会話レコードを作成
    mentioned_users = @status.mentions.includes(:actor).map(&:actor)
    all_participants = ([current_user] + mentioned_users).uniq

    conversation = Conversation.find_or_create_by(
      participants: all_participants.sort_by(&:id)
    )

    @status.update!(conversation: conversation)
  end

  def generate_ap_id_for_status
    @status.ap_id = "#{Rails.application.config.activitypub.base_url}/users/#{current_user.username}/statuses/#{@status.id}"
  end

  def create_poll_for_status
    return if poll_params.blank?

    poll_data = prepare_poll_data
    create_poll_for_status_with_data(poll_data)
  end

  def create_poll_for_status_with_data(poll_data)
    PollCreationService.create_for_status(@status, poll_data)
  end

  def prepare_poll_data
    {
      options: poll_params[:options],
      expires_in: poll_params[:expires_in]&.to_i || 86_400,
      multiple: poll_params[:multiple] == 'true',
      hide_totals: poll_params[:hide_totals] == 'true'
    }
  end
end
