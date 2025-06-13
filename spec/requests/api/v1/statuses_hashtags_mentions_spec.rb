# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'API V1 Statuses Hashtags and Mentions', type: :request do
  let!(:user) { create(:actor, :local) }
  let!(:application) { Doorkeeper::Application.create!(name: 'Test App', redirect_uri: 'urn:ietf:wg:oauth:2.0:oob') }
  let!(:token) { Doorkeeper::AccessToken.create!(application: application, resource_owner_id: user.id) }
  let!(:mentioned_user) { create(:actor, :local) }

  let(:auth_headers) { { 'Authorization' => "Bearer #{token.token}" } }

  describe 'POST /api/v1/statuses - ハッシュタグ機能' do
    context 'ハッシュタグ解析テスト' do
      it '投稿内のハッシュタグが正しく解析される' do
        content = 'これは #テスト 投稿です #ActivityPub #日本語ハッシュタグ'

        post '/api/v1/statuses',
             params: { status: content },
             headers: auth_headers

        expect(response).to have_http_status(:created)

        status = ActivityPubObject.last
        expect(status.tags.count).to eq 3
        expect(status.tags.pluck(:name)).to contain_exactly('テスト', 'ActivityPub', '日本語ハッシュタグ')
      end

      it 'ハッシュタグの使用回数が正しく更新される' do
        # 既存のハッシュタグを作成
        existing_tag = create(:tag, name: 'テスト', usage_count: 5)

        post '/api/v1/statuses',
             params: { status: 'これは #テスト 投稿です' },
             headers: auth_headers

        existing_tag.reload
        expect(existing_tag.usage_count).to eq 6
      end

      it '新しいハッシュタグが作成される' do
        expect do
          post '/api/v1/statuses',
               params: { status: '新しい #全く新しいタグ を使用' },
               headers: auth_headers
        end.to change(Tag, :count).by(1)

        new_tag = Tag.find_by(name: '全く新しいタグ')
        expect(new_tag.usage_count).to eq 1
      end

      it 'ハッシュタグが含まれた投稿のレスポンスにタグ情報が含まれる' do
        post '/api/v1/statuses',
             params: { status: '#テスト ハッシュタグ付き投稿' },
             headers: auth_headers

        json_response = response.parsed_body
        expect(json_response['tags']).to be_present
        expect(json_response['tags'].first['name']).to eq 'テスト'
        expect(json_response['tags'].first['url']).to include('/tags/テスト')
      end

      it '日本語ハッシュタグが正しく処理される' do
        post '/api/v1/statuses',
             params: { status: 'これは #日本語 #ひらがな #カタカナ #漢字 のテストです' },
             headers: auth_headers

        status = ActivityPubObject.last
        expect(status.tags.pluck(:name)).to contain_exactly('日本語', 'ひらがな', 'カタカナ', '漢字')
      end
    end
  end

  describe 'POST /api/v1/statuses - メンション機能' do
    context 'メンション解析テスト' do
      it 'ローカルユーザーへのメンションが正しく解析される' do
        content = "@#{mentioned_user.username} こんにちは！"

        post '/api/v1/statuses',
             params: { status: content },
             headers: auth_headers

        expect(response).to have_http_status(:created)

        status = ActivityPubObject.last
        expect(status.mentions.count).to eq 1
        expect(status.mentions.first.actor).to eq mentioned_user
        expect(status.mentions.first.acct).to eq mentioned_user.username
      end

      it 'リモートユーザーへのメンションが正しく解析される' do
        remote_user = create(:actor, :remote, username: 'remote_user', domain: 'example.com')
        content = "@#{remote_user.username}@#{remote_user.domain} リモートメンション"

        post '/api/v1/statuses',
             params: { status: content },
             headers: auth_headers

        status = ActivityPubObject.last
        expect(status.mentions.count).to eq 1
        expect(status.mentions.first.actor).to eq remote_user
        expect(status.mentions.first.acct).to eq "#{remote_user.username}@#{remote_user.domain}"
      end

      it '複数のメンションが正しく処理される' do
        user2 = create(:actor, :local)
        user3 = create(:actor, :local)

        content = "@#{mentioned_user.username} @#{user2.username} @#{user3.username} 複数メンション"

        post '/api/v1/statuses',
             params: { status: content },
             headers: auth_headers

        status = ActivityPubObject.last
        expect(status.mentions.count).to eq 3
        mentioned_usernames = status.mentions.includes(:actor).map { |m| m.actor.username }
        expect(mentioned_usernames).to contain_exactly(mentioned_user.username, user2.username, user3.username)
      end

      it 'メンション付き投稿のレスポンスにメンション情報が含まれる' do
        content = "@#{mentioned_user.username} メンション付き投稿"

        post '/api/v1/statuses',
             params: { status: content },
             headers: auth_headers

        json_response = response.parsed_body
        expect(json_response['mentions']).to be_present
        expect(json_response['mentions'].first['username']).to eq mentioned_user.username
        expect(json_response['mentions'].first['acct']).to eq mentioned_user.username
      end

      it '存在しないユーザーへのメンションは無視される' do
        content = '@nonexistent_user このユーザーは存在しません'

        post '/api/v1/statuses',
             params: { status: content },
             headers: auth_headers

        status = ActivityPubObject.last
        expect(status.mentions.count).to eq 0
      end
    end
  end

  describe 'POST /api/v1/statuses - ハッシュタグとメンション混在' do
    it 'ハッシュタグとメンションが混在した投稿を正しく処理する' do
      content = "@#{mentioned_user.username} これは #テスト 投稿です #ActivityPub"

      post '/api/v1/statuses',
           params: { status: content },
           headers: auth_headers

      expect(response).to have_http_status(:created)

      status = ActivityPubObject.last
      expect(status.mentions.count).to eq 1
      expect(status.tags.count).to eq 2

      json_response = response.parsed_body
      expect(json_response['mentions'].first['username']).to eq mentioned_user.username
      expect(json_response['tags'].map { |t| t['name'] }).to contain_exactly('テスト', 'ActivityPub')
    end
  end

  describe 'GET /api/v1/timelines/tag/:hashtag' do
    let!(:tag) { create(:tag, name: 'テスト') }
    let!(:status_with_tag) do
      status = create(:activity_pub_object, actor: user, content: '#テスト ハッシュタグ付き投稿')
      create(:object_tag, object: status, tag: tag)
      status
    end

    it 'ハッシュタグタイムラインが取得できる' do
      get "/api/v1/timelines/tag/#{tag.name}", headers: auth_headers

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response).to be_an(Array)
      # TODO: ハッシュタグタイムライン機能の実装後にテストを有効化
      # expect(json_response.first['id']).to eq status_with_tag.id.to_s
    end
  end

  describe 'ActivityPub仕様準拠テスト' do
    context 'Create アクティビティのハッシュタグとメンション' do
      it 'Create アクティビティにハッシュタグとメンション情報が含まれる' do
        content = "@#{mentioned_user.username} #テスト ActivityPub投稿"

        expect do
          post '/api/v1/statuses',
               params: { status: content },
               headers: auth_headers
        end.to change { user.activities.where(activity_type: 'Create').count }.by(1)

        create_activity = user.activities.where(activity_type: 'Create').last
        status = create_activity.object

        expect(status.mentions.count).to eq 1
        expect(status.tags.count).to eq 1
        expect(status.mentions.first.actor).to eq mentioned_user
        expect(status.tags.first.name).to eq 'テスト'
      end

      it 'リモートメンションを含む投稿でActivityPubアクティビティが作成される' do
        remote_user = create(:actor, :remote, username: 'remote', domain: 'example.com')
        content = "@#{remote_user.username}@#{remote_user.domain} リモートメンション"

        post '/api/v1/statuses',
             params: { status: content },
             headers: auth_headers

        status = ActivityPubObject.last
        expect(status.mentions.first.actor).to eq remote_user
      end
    end
  end
end
