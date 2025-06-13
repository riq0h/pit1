# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'API V1 Statuses Reblog', type: :request do
  let!(:user) { create(:actor, :local) }
  let!(:application) { Doorkeeper::Application.create!(name: 'Test App', redirect_uri: 'urn:ietf:wg:oauth:2.0:oob') }
  let!(:token) { Doorkeeper::AccessToken.create!(application: application, resource_owner_id: user.id) }
  let!(:other_user) { create(:actor, :local) }
  let!(:other_status) { create(:activity_pub_object, actor: other_user, object_type: 'Note', content: '他のユーザーの投稿') }

  let(:auth_headers) { { 'Authorization' => "Bearer #{token.token}" } }

  describe 'POST /api/v1/statuses/:id/reblog' do
    context 'Mastodon API互換性テスト' do
      it '他のユーザーの投稿をリブログできる' do
        expect do
          post "/api/v1/statuses/#{other_status.id}/reblog", headers: auth_headers
        end.to change { user.reblogs.count }.by(1)

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body
        expect(json_response['reblogged']).to be true
        expect(json_response['reblogs_count']).to eq 1
      end

      it '投稿のリブログ数が正しく更新される' do
        post "/api/v1/statuses/#{other_status.id}/reblog", headers: auth_headers

        other_status.reload
        expect(other_status.reblogs_count).to eq 1
      end

      it '自分の投稿はリブログできない' do
        own_status = create(:activity_pub_object, actor: user, object_type: 'Note', content: '自分の投稿')

        post "/api/v1/statuses/#{own_status.id}/reblog", headers: auth_headers

        expect(response).to have_http_status(:unprocessable_content)
        json_response = response.parsed_body
        expect(json_response['error']).to eq 'Cannot reblog own status'
      end

      it '既にリブログ済みの投稿は重複してリブログされない' do
        create(:reblog, actor: user, object: other_status)

        expect do
          post "/api/v1/statuses/#{other_status.id}/reblog", headers: auth_headers
        end.not_to(change { user.reblogs.count })

        expect(response).to have_http_status(:ok)
      end

      it '認証なしではリブログできない' do
        post "/api/v1/statuses/#{other_status.id}/reblog"
        expect(response).to have_http_status(:unauthorized)
      end

      it '存在しない投稿をリブログしようとすると404エラー' do
        post '/api/v1/statuses/99999/reblog', headers: auth_headers
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'ActivityPub仕様準拠テスト' do
      it 'リブログ時にAnnounceアクティビティが作成される' do
        expect do
          post "/api/v1/statuses/#{other_status.id}/reblog", headers: auth_headers
        end.to change { user.activities.where(activity_type: 'Announce').count }.by(1)

        announce_activity = user.activities.where(activity_type: 'Announce').last
        expect(announce_activity.object).to eq other_status
        expect(announce_activity.ap_id).to include('#announce-')
        expect(announce_activity.local).to be true
      end

      it 'リモートユーザーの投稿をリブログした場合、Announceアクティビティが投稿者に配信される' do
        remote_user = create(:actor, :remote)
        remote_status = create(:activity_pub_object, actor: remote_user, object_type: 'Note')

        expect(SendActivityJob).to receive(:perform_later).with(anything, array_including(remote_user.inbox_url))

        post "/api/v1/statuses/#{remote_status.id}/reblog", headers: auth_headers
      end

      it 'パブリック投稿をリブログした場合、フォロワーにもAnnounceアクティビティが配信される' do
        # フォロワーを作成
        follower = create(:actor, :remote)
        create(:follow, actor: follower, target_actor: user)

        # パブリック投稿をリブログ
        public_status = create(:activity_pub_object, actor: other_user, object_type: 'Note', visibility: 'public')

        expect(SendActivityJob).to receive(:perform_later).with(anything, array_including(follower.inbox_url))

        post "/api/v1/statuses/#{public_status.id}/reblog", headers: auth_headers
      end

      it 'ローカルユーザーの投稿をリブログした場合、投稿者には配信されない' do
        expect(SendActivityJob).not_to receive(:perform_later)

        post "/api/v1/statuses/#{other_status.id}/reblog", headers: auth_headers
      end
    end
  end

  describe 'POST /api/v1/statuses/:id/unreblog' do
    let!(:reblog) { create(:reblog, actor: user, object: other_status) }

    context 'Mastodon API互換性テスト' do
      it 'リブログを取り消せる' do
        expect do
          post "/api/v1/statuses/#{other_status.id}/unreblog", headers: auth_headers
        end.to change { user.reblogs.count }.by(-1)

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body
        expect(json_response['reblogged']).to be false
        expect(json_response['reblogs_count']).to eq 0
      end

      it '投稿のリブログ数が正しく更新される' do
        other_status.update!(reblogs_count: 1)

        post "/api/v1/statuses/#{other_status.id}/unreblog", headers: auth_headers

        other_status.reload
        expect(other_status.reblogs_count).to eq 0
      end

      it 'リブログしていない投稿のunreblogは何もしない' do
        non_reblogged_status = create(:activity_pub_object, actor: other_user, object_type: 'Note')

        expect do
          post "/api/v1/statuses/#{non_reblogged_status.id}/unreblog", headers: auth_headers
        end.not_to(change { user.reblogs.count })

        expect(response).to have_http_status(:ok)
      end
    end

    context 'ActivityPub仕様準拠テスト' do
      it 'リブログ取り消し時にUndoアクティビティが作成される' do
        expect do
          post "/api/v1/statuses/#{other_status.id}/unreblog", headers: auth_headers
        end.to change { user.activities.where(activity_type: 'Undo').count }.by(1)

        undo_activity = user.activities.where(activity_type: 'Undo').last
        expect(undo_activity.target_ap_id).to include('#announce-')
        expect(undo_activity.local).to be true
      end

      it 'リモートユーザーの投稿のリブログを取り消した場合、Undoアクティビティが配信される' do
        remote_user = create(:actor, :remote)
        remote_status = create(:activity_pub_object, actor: remote_user, object_type: 'Note')
        reblog = create(:reblog, actor: user, object: remote_status)

        expect(SendActivityJob).to receive(:perform_later).with(anything, array_including(remote_user.inbox_url))

        post "/api/v1/statuses/#{remote_status.id}/unreblog", headers: auth_headers
      end
    end
  end

  describe 'ActivityPub連合テスト' do
    context 'リモートからのAnnounceアクティビティ受信' do
      let(:remote_user) { create(:actor, :remote) }
      let(:local_status) { create(:activity_pub_object, actor: user, object_type: 'Note') }

      it 'リモートユーザーからのAnnounceアクティビティを正しく処理する' do
        announce_activity = {
          '@context' => 'https://www.w3.org/ns/activitystreams',
          'type' => 'Announce',
          'actor' => remote_user.ap_id,
          'object' => local_status.ap_id,
          'id' => "#{remote_user.ap_id}#announces/#{SecureRandom.uuid}"
        }

        expect do
          # ActivityProcessorがAnnounceアクティビティを処理することをテスト
          ActivityProcessor.new(announce_activity, remote_user).process
        end.to change { local_status.reblogs.count }.by(1)
      end
    end
  end
end
