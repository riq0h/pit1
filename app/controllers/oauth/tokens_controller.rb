# frozen_string_literal: true

module Oauth
  class TokensController < Doorkeeper::TokensController
    # Doorkeeperが全てのトークン操作を処理
    # このコントローラはDoorkeeperのTokensControllerを継承し
    # トークンエンドポイント機能を提供
  end
end
