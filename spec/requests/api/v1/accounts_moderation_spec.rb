# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'API V1 Accounts Moderation', type: :request do
  let!(:user) { create(:actor, :local) }
  let!(:application) { Doorkeeper::Application.create!(name: 'Test App', redirect_uri: 'urn:ietf:wg:oauth:2.0:oob') }
  let!(:token) { Doorkeeper::AccessToken.create!(application: application, resource_owner_id: user.id) }
  let!(:target_user) { create(:actor, :local) }
  let!(:remote_user) { create(:actor, :remote) }

  let(:auth_headers) { { 'Authorization' => "Bearer #{token.token}" } }

  describe 'POST /api/v1/accounts/:id/block' do
    context 'ブロック機能テスト' do
      it 'ユーザーをブロックできる' do
        expect do
          post "/api/v1/accounts/#{target_user.id}/block", headers: auth_headers
        end.to change { user.blocks.count }.by(1)

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body
        expect(json_response['blocking']).to be true
        expect(json_response['id']).to eq target_user.id.to_s
      end

      it 'ブロック時に既存のフォロー関係が削除される' do
        # 先にフォロー関係を作成
        create(:follow, actor: user, target_actor: target_user)

        expect do
          post "/api/v1/accounts/#{target_user.id}/block", headers: auth_headers
        end.to change { user.follows.count }.by(-1)

        expect(user.follows.where(target_actor: target_user)).to be_empty
      end

      it '自分自身をブロックしようとするとエラー' do
        post "/api/v1/accounts/#{user.id}/block", headers: auth_headers

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = response.parsed_body
        expect(json_response['error']).to eq 'Cannot block yourself'
      end

      it '既にブロック済みのユーザーを再度ブロックしても重複しない' do
        create(:block, actor: user, target_actor: target_user)

        expect do
          post "/api/v1/accounts/#{target_user.id}/block", headers: auth_headers
        end.not_to(change { user.blocks.count })

        expect(response).to have_http_status(:ok)
      end

      it 'リモートユーザーもブロックできる' do
        expect do
          post "/api/v1/accounts/#{remote_user.id}/block", headers: auth_headers
        end.to change { user.blocks.count }.by(1)

        block = user.blocks.last
        expect(block.target_actor).to eq remote_user
      end

      it '認証なしではブロックできない' do
        post "/api/v1/accounts/#{target_user.id}/block"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/accounts/:id/unblock' do
    let!(:block) { create(:block, actor: user, target_actor: target_user) }

    context 'ブロック解除テスト' do
      it 'ユーザーのブロックを解除できる' do
        expect do
          post "/api/v1/accounts/#{target_user.id}/unblock", headers: auth_headers
        end.to change { user.blocks.count }.by(-1)

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body
        expect(json_response['blocking']).to be false
      end

      it 'ブロックしていないユーザーのunblockは何もしない' do
        non_blocked_user = create(:actor, :local)

        expect do
          post "/api/v1/accounts/#{non_blocked_user.id}/unblock", headers: auth_headers
        end.not_to(change { user.blocks.count })

        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe 'POST /api/v1/accounts/:id/mute' do
    context 'ミュート機能テスト' do
      it 'ユーザーをミュートできる' do
        expect do
          post "/api/v1/accounts/#{target_user.id}/mute", headers: auth_headers
        end.to change { user.mutes.count }.by(1)

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body
        expect(json_response['muting']).to be true
        expect(json_response['muting_notifications']).to be true
      end

      it '通知をミュートしない設定でミュートできる' do
        post "/api/v1/accounts/#{target_user.id}/mute",
             params: { notifications: false },
             headers: auth_headers

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body
        expect(json_response['muting']).to be true
        expect(json_response['muting_notifications']).to be false

        mute = user.mutes.last
        expect(mute.notifications).to be false
      end

      it '自分自身をミュートしようとするとエラー' do
        post "/api/v1/accounts/#{user.id}/mute", headers: auth_headers

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = response.parsed_body
        expect(json_response['error']).to eq 'Cannot mute yourself'
      end

      it '既にミュート済みのユーザーの設定を更新できる' do
        create(:mute, actor: user, target_actor: target_user, notifications: false)

        post "/api/v1/accounts/#{target_user.id}/mute",
             params: { notifications: true },
             headers: auth_headers

        mute = user.mutes.find_by(target_actor: target_user)
        expect(mute.notifications).to be true
      end
    end
  end

  describe 'POST /api/v1/accounts/:id/unmute' do
    let!(:mute) { create(:mute, actor: user, target_actor: target_user) }

    context 'ミュート解除テスト' do
      it 'ユーザーのミュートを解除できる' do
        expect do
          post "/api/v1/accounts/#{target_user.id}/unmute", headers: auth_headers
        end.to change { user.mutes.count }.by(-1)

        expect(response).to have_http_status(:ok)
        json_response = response.parsed_body
        expect(json_response['muting']).to be false
        expect(json_response['muting_notifications']).to be false
      end

      it 'ミュートしていないユーザーのunmuteは何もしない' do
        non_muted_user = create(:actor, :local)

        expect do
          post "/api/v1/accounts/#{non_muted_user.id}/unmute", headers: auth_headers
        end.not_to(change { user.mutes.count })

        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe 'GET /api/v1/domain_blocks' do
    let!(:domain_block1) { create(:domain_block, actor: user, domain: 'blocked1.example') }
    let!(:domain_block2) { create(:domain_block, actor: user, domain: 'blocked2.example') }

    it 'ドメインブロック一覧を取得できる' do
      get '/api/v1/domain_blocks', headers: auth_headers

      expect(response).to have_http_status(:ok)
      json_response = response.parsed_body
      expect(json_response).to be_an(Array)
      expect(json_response).to contain_exactly('blocked1.example', 'blocked2.example')
    end

    it '認証なしでは一覧を取得できない' do
      get '/api/v1/domain_blocks'
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'POST /api/v1/domain_blocks' do
    context 'ドメインブロック機能テスト' do
      it 'ドメインをブロックできる' do
        expect do
          post '/api/v1/domain_blocks',
               params: { domain: 'malicious.example' },
               headers: auth_headers
        end.to change { user.domain_blocks.count }.by(1)

        expect(response).to have_http_status(:created)

        domain_block = user.domain_blocks.last
        expect(domain_block.domain).to eq 'malicious.example'
      end

      it 'ドメイン名が正規化される' do
        post '/api/v1/domain_blocks',
             params: { domain: '  EXAMPLE.COM  ' },
             headers: auth_headers

        domain_block = user.domain_blocks.last
        expect(domain_block.domain).to eq 'example.com'
      end

      it '既にブロック済みのドメインは重複してブロックされない' do
        create(:domain_block, actor: user, domain: 'example.com')

        expect do
          post '/api/v1/domain_blocks',
               params: { domain: 'example.com' },
               headers: auth_headers
        end.not_to(change { user.domain_blocks.count })

        expect(response).to have_http_status(:created)
      end

      it 'ドメイン名が空の場合はエラー' do
        post '/api/v1/domain_blocks',
             params: { domain: '' },
             headers: auth_headers

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = response.parsed_body
        expect(json_response['error']).to eq 'Domain parameter is required'
      end
    end
  end

  describe 'DELETE /api/v1/domain_blocks' do
    let!(:domain_block) { create(:domain_block, actor: user, domain: 'blocked.example') }

    context 'ドメインブロック解除テスト' do
      it 'ドメインブロックを解除できる' do
        expect do
          delete '/api/v1/domain_blocks',
                 params: { domain: 'blocked.example' },
                 headers: auth_headers
        end.to change { user.domain_blocks.count }.by(-1)

        expect(response).to have_http_status(:ok)
      end

      it 'ブロックしていないドメインの解除は404エラー' do
        delete '/api/v1/domain_blocks',
               params: { domain: 'notblocked.example' },
               headers: auth_headers

        expect(response).to have_http_status(:not_found)
        json_response = response.parsed_body
        expect(json_response['error']).to eq 'Domain not found in blocks'
      end
    end
  end

  describe 'タイムラインフィルタリングテスト' do
    let!(:blocked_user) { create(:actor, :local) }
    let!(:muted_user) { create(:actor, :local) }
    let!(:domain_blocked_user) { create(:actor, :remote, domain: 'blocked.example') }

    before do
      create(:block, actor: user, target_actor: blocked_user)
      create(:mute, actor: user, target_actor: muted_user)
      create(:domain_block, actor: user, domain: 'blocked.example')
    end

    it 'ブロックしたユーザーの投稿がタイムラインに表示されない' do
      blocked_status = create(:activity_pub_object, actor: blocked_user, object_type: 'Note')
      normal_status = create(:activity_pub_object, actor: target_user, object_type: 'Note')

      get '/api/v1/timelines/public', headers: auth_headers

      json_response = response.parsed_body
      status_ids = json_response.map { |s| s['id'] }
      expect(status_ids).to include(normal_status.id.to_s)
      expect(status_ids).not_to include(blocked_status.id.to_s)
    end

    it 'ミュートしたユーザーの投稿がタイムラインに表示されない' do
      muted_status = create(:activity_pub_object, actor: muted_user, object_type: 'Note')
      normal_status = create(:activity_pub_object, actor: target_user, object_type: 'Note')

      get '/api/v1/timelines/public', headers: auth_headers

      json_response = response.parsed_body
      status_ids = json_response.map { |s| s['id'] }
      expect(status_ids).to include(normal_status.id.to_s)
      expect(status_ids).not_to include(muted_status.id.to_s)
    end

    it 'ドメインブロックしたユーザーの投稿がタイムラインに表示されない' do
      domain_blocked_status = create(:activity_pub_object, actor: domain_blocked_user, object_type: 'Note')
      normal_status = create(:activity_pub_object, actor: target_user, object_type: 'Note')

      get '/api/v1/timelines/public', headers: auth_headers

      json_response = response.parsed_body
      status_ids = json_response.map { |s| s['id'] }
      expect(status_ids).to include(normal_status.id.to_s)
      expect(status_ids).not_to include(domain_blocked_status.id.to_s)
    end
  end
end
