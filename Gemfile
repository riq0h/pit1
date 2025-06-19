# frozen_string_literal: true

# Gemfile
source 'https://rubygems.org'

ruby '3.4.1'

# Rails 8 Core
gem 'bootsnap', require: false
gem 'dotenv-rails', groups: %i[development test]
gem 'image_processing', '~> 1.2'
gem 'importmap-rails'
gem 'jbuilder'
gem 'ostruct'
gem 'puma', '>= 5.0'
gem 'rails', '~> 8.0.0'
gem 'redis', '>= 4.0.1'
gem 'sassc-rails'
gem 'sprockets-rails'
gem 'sqlite3', '>= 2.1'
gem 'stimulus-rails'
gem 'tailwindcss-rails'
gem 'turbo-rails'

# ActivityPub & Federation
gem 'addressable' # URI handling
gem 'httparty' # HTTP requests for federation
gem 'json-ld'                    # JSON-LD processing
gem 'nokogiri'                   # HTML/XML processing
gem 'rsa'                        # RSA key generation for HTTP signatures

# Authentication & Security
gem 'bcrypt', '~> 3.1.7' # Password hashing
gem 'doorkeeper', '~> 5.7'       # OAuth 2.0 server
gem 'jwt'                        # JWT tokens for OAuth
gem 'rack-cors'                  # CORS handling

# Background Jobs
gem 'solid_queue' # Rails 8 solid queue for background jobs

# Push Notifications
gem 'web-push' # Web Push Protocol implementation

# Utilities
gem 'aws-sdk-s3', require: false # S3-compatible storage (Cloudflare R2)
gem 'blurhash'                   # Image placeholder generation
gem 'foreman'
gem 'marcel'                     # MIME type detection
gem 'mini_magick'                # Image processing
gem 'nanoid'                     # Generate short unique IDs

group :development, :test do
  gem 'brakeman'
  gem 'debug', platforms: %i[mri windows]
  gem 'factory_bot_rails'
  gem 'faker'
  gem 'pry-rails'
  gem 'rspec-rails'
  gem 'rubocop', require: false
  gem 'rubocop-performance', require: false
  gem 'rubocop-rails', require: false
  gem 'rubocop-rspec', require: false
end

group :development do
  gem 'annotate'                 # Model annotations
  gem 'bullet'                   # N+1 query detection
  gem 'listen', '~> 3.3'
  gem 'spring'
  gem 'web-console'
end
