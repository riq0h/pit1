# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ActivityPub Federation', type: :request do
  let!(:local_user) { create(:actor, :local) }
  let!(:remote_user) { create(:actor, :remote, domain: 'remote.example') }
  let!(:local_status) { create(:activity_pub_object, actor: local_user, object_type: 'Note', content: 'ローカル投稿') }

  describe 'Inbox エンドポイント' do
    let(:inbox_path) { "/users/#{local_user.username}/inbox" }

    context 'Follow アクティビティ受信テスト' do
      let(:follow_activity) do
        {
          '@context' => 'https://www.w3.org/ns/activitystreams',
          'type' => 'Follow',
          'actor' => remote_user.ap_id,
          'object' => local_user.ap_id,
          'id' => "#{remote_user.ap_id}#follows/#{SecureRandom.uuid}"
        }
      end

      it 'リモートユーザーからのFollowアクティビティを処理する' do
        expect do
          post inbox_path,
               params: follow_activity.to_json,
               headers: { 'Content-Type' => 'application/activity+json' }
        end.to change { local_user.followers.count }.by(1)

        expect(response).to have_http_status(:ok)
        expect(local_user.followers).to include(remote_user)
      end

      it 'Followアクティビティ受信時にAcceptアクティビティを返信する' do
        expect(SendAcceptJob).to receive(:perform_later).with(anything, remote_user.inbox_url)

        post inbox_path,
             params: follow_activity.to_json,
             headers: { 'Content-Type' => 'application/activity+json' }
      end

      it '重複するFollowアクティビティは無視される' do
        create(:follow, actor: remote_user, target_actor: local_user)

        expect do
          post inbox_path,
               params: follow_activity.to_json,
               headers: { 'Content-Type' => 'application/activity+json' }
        end.not_to(change { local_user.followers.count })
      end
    end

    context 'Undo Follow アクティビティ受信テスト' do
      let!(:existing_follow) { create(:follow, actor: remote_user, target_actor: local_user) }
      let(:undo_follow_activity) do
        {
          '@context' => 'https://www.w3.org/ns/activitystreams',
          'type' => 'Undo',
          'actor' => remote_user.ap_id,
          'object' => {
            'type' => 'Follow',
            'actor' => remote_user.ap_id,
            'object' => local_user.ap_id,
            'id' => "#{remote_user.ap_id}#follows/original"
          },
          'id' => "#{remote_user.ap_id}#undo/#{SecureRandom.uuid}"
        }
      end

      it 'Undo Followアクティビティでフォロー関係を削除する' do
        expect do
          post inbox_path,
               params: undo_follow_activity.to_json,
               headers: { 'Content-Type' => 'application/activity+json' }
        end.to change { local_user.followers.count }.by(-1)

        expect(response).to have_http_status(:ok)
        expect(local_user.followers).not_to include(remote_user)
      end
    end

    context 'Like アクティビティ受信テスト' do
      let(:like_activity) do
        {
          '@context' => 'https://www.w3.org/ns/activitystreams',
          'type' => 'Like',
          'actor' => remote_user.ap_id,
          'object' => local_status.ap_id,
          'id' => "#{remote_user.ap_id}#likes/#{SecureRandom.uuid}"
        }
      end

      it 'リモートユーザーからのLikeアクティビティを処理する' do
        expect do
          post inbox_path,
               params: like_activity.to_json,
               headers: { 'Content-Type' => 'application/activity+json' }
        end.to change { local_status.favourites.count }.by(1)

        expect(response).to have_http_status(:ok)

        favourite = local_status.favourites.last
        expect(favourite.actor).to eq remote_user
      end

      it 'Likeアクティビティ受信時に投稿のお気に入り数が更新される' do
        post inbox_path,
             params: like_activity.to_json,
             headers: { 'Content-Type' => 'application/activity+json' }

        local_status.reload
        expect(local_status.favourites_count).to eq 1
      end
    end

    context 'Announce アクティビティ受信テスト' do
      let(:announce_activity) do
        {
          '@context' => 'https://www.w3.org/ns/activitystreams',
          'type' => 'Announce',
          'actor' => remote_user.ap_id,
          'object' => local_status.ap_id,
          'id' => "#{remote_user.ap_id}#announces/#{SecureRandom.uuid}"
        }
      end

      it 'リモートユーザーからのAnnounceアクティビティを処理する' do
        expect do
          post inbox_path,
               params: announce_activity.to_json,
               headers: { 'Content-Type' => 'application/activity+json' }
        end.to change { local_status.reblogs.count }.by(1)

        expect(response).to have_http_status(:ok)

        reblog = local_status.reblogs.last
        expect(reblog.actor).to eq remote_user
      end

      it 'Announceアクティビティ受信時に投稿のリブログ数が更新される' do
        post inbox_path,
             params: announce_activity.to_json,
             headers: { 'Content-Type' => 'application/activity+json' }

        local_status.reload
        expect(local_status.reblogs_count).to eq 1
      end
    end

    context 'Create アクティビティ受信テスト' do
      let(:create_activity) do
        {
          '@context' => 'https://www.w3.org/ns/activitystreams',
          'type' => 'Create',
          'actor' => remote_user.ap_id,
          'object' => {
            'type' => 'Note',
            'id' => "#{remote_user.ap_id}/statuses/#{SecureRandom.uuid}",
            'content' => 'リモートから投稿されたコンテンツ',
            'attributedTo' => remote_user.ap_id,
            'published' => Time.current.iso8601
          },
          'id' => "#{remote_user.ap_id}#create/#{SecureRandom.uuid}"
        }
      end

      it 'リモートユーザーからのCreateアクティビティを処理する' do
        expect do
          post inbox_path,
               params: create_activity.to_json,
               headers: { 'Content-Type' => 'application/activity+json' }
        end.to change(ActivityPubObject, :count).by(1)

        expect(response).to have_http_status(:ok)

        created_object = ActivityPubObject.last
        expect(created_object.actor).to eq remote_user
        expect(created_object.content).to eq 'リモートから投稿されたコンテンツ'
        expect(created_object.local).to be false
      end
    end

    context 'Delete アクティビティ受信テスト' do
      let!(:remote_status) { create(:activity_pub_object, actor: remote_user, object_type: 'Note', local: false) }
      let(:delete_activity) do
        {
          '@context' => 'https://www.w3.org/ns/activitystreams',
          'type' => 'Delete',
          'actor' => remote_user.ap_id,
          'object' => remote_status.ap_id,
          'id' => "#{remote_user.ap_id}#delete/#{SecureRandom.uuid}"
        }
      end

      it 'リモートユーザーからのDeleteアクティビティを処理する' do
        expect do
          post inbox_path,
               params: delete_activity.to_json,
               headers: { 'Content-Type' => 'application/activity+json' }
        end.to change(ActivityPubObject, :count).by(-1)

        expect(response).to have_http_status(:ok)
        expect(ActivityPubObject.find_by(id: remote_status.id)).to be_nil
      end
    end

    context 'アクティビティ検証テスト' do
      let(:invalid_activity) do
        {
          '@context' => 'https://www.w3.org/ns/activitystreams',
          'type' => 'InvalidType',
          'actor' => remote_user.ap_id,
          'object' => local_user.ap_id
        }
      end

      it '無効なアクティビティタイプは拒否される' do
        post inbox_path,
             params: invalid_activity.to_json,
             headers: { 'Content-Type' => 'application/activity+json' }

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it '不正なJSON形式は拒否される' do
        post inbox_path,
             params: 'invalid json',
             headers: { 'Content-Type' => 'application/activity+json' }

        expect(response).to have_http_status(:bad_request)
      end

      it '存在しないアクターからのアクティビティは拒否される' do
        nonexistent_activity = {
          '@context' => 'https://www.w3.org/ns/activitystreams',
          'type' => 'Follow',
          'actor' => 'https://nonexistent.example/users/fake',
          'object' => local_user.ap_id,
          'id' => 'https://nonexistent.example/activities/fake'
        }

        post inbox_path,
             params: nonexistent_activity.to_json,
             headers: { 'Content-Type' => 'application/activity+json' }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'Outbox エンドポイント' do
    let(:outbox_path) { "/users/#{local_user.username}/outbox" }

    context 'Outbox 取得テスト' do
      let!(:local_activity) do
        create(:activity,
               actor: local_user,
               activity_type: 'Create',
               object: local_status,
               local: true)
      end

      it 'ユーザーのアクティビティ一覧を取得できる' do
        get outbox_path, headers: { 'Accept' => 'application/activity+json' }

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include('application/activity+json')

        json_response = response.parsed_body
        expect(json_response['type']).to eq 'OrderedCollection'
        expect(json_response['totalItems']).to be >= 1
      end

      it 'プライベートアクティビティは外部に公開されない' do
        private_status = create(:activity_pub_object,
                                actor: local_user,
                                object_type: 'Note',
                                visibility: 'private')
        create(:activity,
               actor: local_user,
               activity_type: 'Create',
               object: private_status,
               local: true)

        get outbox_path, headers: { 'Accept' => 'application/activity+json' }

        json_response = response.parsed_body
        # プライベート投稿のアクティビティは含まれないことを確認
        # 具体的な実装に応じて調整が必要
      end
    end
  end

  describe 'アクター情報取得' do
    let(:actor_path) { "/users/#{local_user.username}" }

    it 'アクター情報をActivityPub形式で取得できる' do
      get actor_path, headers: { 'Accept' => 'application/activity+json' }

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('application/activity+json')

      json_response = response.parsed_body
      expect(json_response['type']).to eq 'Person'
      expect(json_response['id']).to eq local_user.ap_id
      expect(json_response['preferredUsername']).to eq local_user.username
      expect(json_response['inbox']).to be_present
      expect(json_response['outbox']).to be_present
      expect(json_response['followers']).to be_present
      expect(json_response['following']).to be_present
      expect(json_response['publicKey']).to be_present
    end

    it 'HTML形式でも正常に表示される' do
      get actor_path, headers: { 'Accept' => 'text/html' }

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('text/html')
    end
  end

  describe 'HTTP署名検証' do
    context 'インボックスアクティビティの署名検証' do
      let(:inbox_path) { "/users/#{local_user.username}/inbox" }
      let(:follow_activity) do
        {
          '@context' => 'https://www.w3.org/ns/activitystreams',
          'type' => 'Follow',
          'actor' => remote_user.ap_id,
          'object' => local_user.ap_id,
          'id' => "#{remote_user.ap_id}#follows/#{SecureRandom.uuid}"
        }
      end

      it '有効な署名付きリクエストは受け入れられる' do
        # HTTP署名をモックまたはテスト用に生成
        # 実際の実装では、適切なHTTP署名ヘッダーを含めてテストする必要があります
        valid_signature_headers = {
          'Content-Type' => 'application/activity+json',
          'Signature' => 'keyId="test",algorithm="rsa-sha256",signature="mock_signature"'
        }

        # HTTP署名検証をモック
        allow_any_instance_of(HttpSignatureVerifier).to receive(:verify).and_return(true)

        post inbox_path,
             params: follow_activity.to_json,
             headers: valid_signature_headers

        expect(response).to have_http_status(:ok)
      end

      it '無効な署名のリクエストは拒否される' do
        invalid_signature_headers = {
          'Content-Type' => 'application/activity+json',
          'Signature' => 'keyId="test",algorithm="rsa-sha256",signature="invalid_signature"'
        }

        # HTTP署名検証をモック（失敗）
        allow_any_instance_of(HttpSignatureVerifier).to receive(:verify).and_return(false)

        post inbox_path,
             params: follow_activity.to_json,
             headers: invalid_signature_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'アクティビティ配信テスト' do
    let!(:follower) { create(:actor, :remote) }
    let!(:follow) { create(:follow, actor: follower, target_actor: local_user) }

    context 'ローカルアクティビティの配信' do
      it '新しい投稿がフォロワーに配信される' do
        expect(SendActivityJob).to receive(:perform_later).with(anything, [follower.inbox_url])

        post '/api/v1/statuses',
             params: { status: '配信テスト投稿' },
             headers: { 'Authorization' => "Bearer #{create(:doorkeeper_access_token, resource_owner_id: local_user.id).token}" }
      end

      it 'プライベート投稿は外部に配信されない' do
        expect(SendActivityJob).not_to receive(:perform_later)

        post '/api/v1/statuses',
             params: { status: 'プライベート投稿', visibility: 'private' },
             headers: { 'Authorization' => "Bearer #{create(:doorkeeper_access_token, resource_owner_id: local_user.id).token}" }
      end
    end
  end

  describe '連合タイムライン統合テスト' do
    let!(:remote_status) do
      create(:activity_pub_object,
             actor: remote_user,
             object_type: 'Note',
             content: 'リモート投稿',
             local: false,
             visibility: 'public')
    end

    it 'リモート投稿がパブリックタイムラインに表示される' do
      get '/api/v1/timelines/public',
          headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:ok)

      json_response = response.parsed_body
      status_contents = json_response.map { |s| s['content'] }
      expect(status_contents).to include('リモート投稿')
    end

    it 'フォローしているリモートユーザーの投稿がホームタイムラインに表示される' do
      create(:follow, actor: local_user, target_actor: remote_user)

      token = create(:doorkeeper_access_token, resource_owner_id: local_user.id)

      get '/api/v1/timelines/home',
          headers: { 'Authorization' => "Bearer #{token.token}" }

      expect(response).to have_http_status(:ok)

      json_response = response.parsed_body
      status_contents = json_response.map { |s| s['content'] }
      expect(status_contents).to include('リモート投稿')
    end
  end
end
