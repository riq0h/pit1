# 開発環境と本番環境の統合設定
# シンプルさのためSQLiteとSolid Queueを使用

ARG RUBY_VERSION=3.4.1
FROM ruby:$RUBY_VERSION-slim

# システム依存関係をインストール
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential \
    libsqlite3-dev \
    nodejs \
    npm \
    curl \
    git \
    jq \
    procps \
    && rm -rf /var/lib/apt/lists/*

# ワーキングディレクトリを設定
WORKDIR /app

# 依存関係ファイルをコピー
COPY Gemfile Gemfile.lock ./
COPY package*.json ./

# 依存関係をインストール
RUN bundle install
RUN npm install

# アプリケーションコードをコピー
COPY . .

# 必要なディレクトリを適切な権限で作成
RUN mkdir -p \
    tmp/pids \
    tmp/cache \
    log \
    db \
    public/system/accounts/avatars \
    public/system/accounts/headers \
    public/system/media_attachments \
    && chmod -R 755 public/system

# エントリーポイントスクリプトをコピー
COPY docker/entrypoint.sh /usr/bin/entrypoint.sh
RUN chmod +x /usr/bin/entrypoint.sh

# セキュリティのため非rootユーザを作成
RUN groupadd --system --gid 1000 letter && \
    useradd letter --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    chown -R letter:letter /app

USER letter

# ポートを公開
EXPOSE 3000

# エントリーポイントを設定
ENTRYPOINT ["entrypoint.sh"]

# デフォルトコマンド
CMD ["rails", "server", "-b", "0.0.0.0"]