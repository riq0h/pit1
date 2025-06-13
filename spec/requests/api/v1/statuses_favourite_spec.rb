# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'API V1 Statuses Favourite', type: :request do
  let!(:user) { create(:actor, :local) }
  let!(:application) { Doorkeeper::Application.create!(name: 'Test App', redirect_uri: 'urn:ietf:wg:oauth:2.0:oob') }
  let!(:token) { Doorkeeper::AccessToken.create!(application: application, resource_owner_id: user.id) }
  let!(:status) { create(:activity_pub_object, actor: user, object_type: 'Note', content: 'テスト投稿') }
  let!(:other_user) { create(:actor, :local) }
  let!(:other_status) { create(:activity_pub_object, actor: other_user, object_type: 'Note', content: '他のユーザーの投稿') }

  let(:auth_headers) { { 'Authorization' => "Bearer #{token.token}" } }

  describe 'POST /api/v1/statuses/:id/favourite' do
    context 'Mastodon API互換性テスト' do
      it '自分以外の投稿をお気に入りに追加できる' do
        expect do
          post "/api/v1/statuses/#{other_status.id}/favourite", headers: auth_headers
        end.to change { user.favourites.count }.by(1)

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['favourited']).to be true
        expect(json_response['favourites_count']).to eq 1
      end

      it '投稿のお気に入り数が正しく更新される' do
        post "/api/v1/statuses/#{other_status.id}/favourite", headers: auth_headers

        other_status.reload
        expect(other_status.favourites_count).to eq 1
      end

      it '既にお気に入りに追加済みの投稿は重複してお気に入りに追加されない' do
        create(:favourite, actor: user, object: other_status)

        expect do
          post "/api/v1/statuses/#{other_status.id}/favourite", headers: auth_headers
        end.not_to(change { user.favourites.count })

        expect(response).to have_http_status(:ok)
      end

      it '認証なしではお気に入りに追加できない' do
        post "/api/v1/statuses/#{other_status.id}/favourite"
        expect(response).to have_http_status(:unauthorized)
      end

      it '存在しない投稿をお気に入りに追加しようとすると404エラー' do
        post '/api/v1/statuses/99999/favourite', headers: auth_headers
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'ActivityPub仕様準拠テスト' do
      it 'お気に入り追加時にLikeアクティビティが作成される' do
        expect do
          post "/api/v1/statuses/#{other_status.id}/favourite", headers: auth_headers
        end.to change { user.activities.where(activity_type: 'Like').count }.by(1)

        like_activity = user.activities.where(activity_type: 'Like').last
        expect(like_activity.object).to eq other_status
        expect(like_activity.ap_id).to include('#like-')
        expect(like_activity.local).to be true
      end

      it 'リモートユーザーの投稿をお気に入りに追加した場合、Likeアクティビティが配信される' do
        remote_user = create(:actor, :remote)
        remote_status = create(:activity_pub_object, actor: remote_user, object_type: 'Note')

        expect(SendActivityJob).to receive(:perform_later).with(anything, [remote_user.inbox_url])

        post "/api/v1/statuses/#{remote_status.id}/favourite", headers: auth_headers
      end

      it 'ローカルユーザーの投稿をお気に入りに追加した場合、アクティビティは配信されない' do
        expect(SendActivityJob).not_to receive(:perform_later)

        post "/api/v1/statuses/#{other_status.id}/favourite", headers: auth_headers
      end
    end
  end

  describe 'POST /api/v1/statuses/:id/unfavourite' do
    let!(:favourite) { create(:favourite, actor: user, object: other_status) }

    context 'Mastodon API互換性テスト' do
      it 'お気に入りから削除できる' do
        expect do
          post "/api/v1/statuses/#{other_status.id}/unfavourite", headers: auth_headers
        end.to change { user.favourites.count }.by(-1)

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['favourited']).to be false
        expect(json_response['favourites_count']).to eq 0
      end

      it '投稿のお気に入り数が正しく更新される' do
        other_status.update!(favourites_count: 1)

        post "/api/v1/statuses/#{other_status.id}/unfavourite", headers: auth_headers

        other_status.reload
        expect(other_status.favourites_count).to eq 0
      end

      it 'お気に入りに追加していない投稿のunfavouriteは何もしない' do
        non_favourited_status = create(:activity_pub_object, actor: other_user, object_type: 'Note')

        expect do
          post "/api/v1/statuses/#{non_favourited_status.id}/unfavourite", headers: auth_headers
        end.not_to(change { user.favourites.count })

        expect(response).to have_http_status(:ok)
      end
    end

    context 'ActivityPub仕様準拠テスト' do
      it 'お気に入り削除時にUndoアクティビティが作成される' do
        expect do
          post "/api/v1/statuses/#{other_status.id}/unfavourite", headers: auth_headers
        end.to change { user.activities.where(activity_type: 'Undo').count }.by(1)

        undo_activity = user.activities.where(activity_type: 'Undo').last
        expect(undo_activity.target_ap_id).to include('#like-')
        expect(undo_activity.local).to be true
      end

      it 'リモートユーザーの投稿のお気に入りを削除した場合、Undoアクティビティが配信される' do
        remote_user = create(:actor, :remote)
        remote_status = create(:activity_pub_object, actor: remote_user, object_type: 'Note')
        favourite = create(:favourite, actor: user, object: remote_status)

        expect(SendActivityJob).to receive(:perform_later).with(anything, [remote_user.inbox_url])

        post "/api/v1/statuses/#{remote_status.id}/unfavourite", headers: auth_headers
      end
    end
  end
end
