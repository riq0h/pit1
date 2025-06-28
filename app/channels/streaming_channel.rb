# frozen_string_literal: true

class StreamingChannel < ApplicationCable::Channel
  def subscribed
    stream_type = params[:stream] || 'user'

    case stream_type
    when 'user'
      stream_for_user
    when 'public'
      stream_from 'timeline:public'
    when 'public:local'
      stream_from 'timeline:public:local'
    when /\Ahashtag(?::local)?\z/
      stream_hashtag(stream_type.include?('local'))
    when /\Alist:\d+\z/
      stream_list(stream_type.split(':').last)
    else
      reject
    end
  end

  def unsubscribed
    # クリーンアップ処理
  end

  private

  def stream_for_user
    # ユーザ固有のストリーム
    stream_from "timeline:user:#{current_user.id}"

    # ホームタイムライン（フォロー中のユーザ）
    stream_from "timeline:home:#{current_user.id}"

    # 通知ストリーム
    stream_from "notifications:#{current_user.id}"
  end

  def stream_hashtag(local_only: false)
    hashtag = params[:tag]&.downcase
    return reject if hashtag.blank?

    stream_name = local_only ? "hashtag:#{hashtag}:local" : "hashtag:#{hashtag}"
    stream_from stream_name
  end

  def stream_list(list_id)
    list = current_user.lists.find_by(id: list_id)
    return reject unless list

    stream_from "list:#{list_id}"
  end
end
