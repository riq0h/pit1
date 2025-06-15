# Letter ActivityPub Instance
# Unified configuration for both development and production
# Uses SQLite and Solid Queue for simplicity

ARG RUBY_VERSION=3.4.1
FROM ruby:$RUBY_VERSION-slim

# Install system dependencies
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

# Set working directory
WORKDIR /app

# Copy dependency files
COPY Gemfile Gemfile.lock ./
COPY package*.json ./

# Install dependencies
RUN bundle install
RUN npm install

# Copy application code
COPY . .

# Create necessary directories with proper permissions
RUN mkdir -p \
    tmp/pids \
    tmp/cache \
    log \
    db \
    public/system/accounts/avatars \
    public/system/accounts/headers \
    public/system/media_attachments \
    && chmod -R 755 public/system

# Copy entrypoint script
COPY docker/entrypoint.sh /usr/bin/entrypoint.sh
RUN chmod +x /usr/bin/entrypoint.sh

# Create non-root user for security
RUN groupadd --system --gid 1000 letter && \
    useradd letter --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    chown -R letter:letter /app

USER letter

# Expose port
EXPOSE 3000

# Set entrypoint
ENTRYPOINT ["entrypoint.sh"]

# Default command
CMD ["rails", "server", "-b", "0.0.0.0"]