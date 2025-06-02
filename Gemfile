# Gemfile
source "https://rubygems.org"

ruby "3.4.1"

# Rails 8 Core
gem "rails", "~> 8.0.0"
gem "sqlite3", ">= 2.1"
gem "puma", ">= 5.0"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "jbuilder"
gem "redis", ">= 4.0.1"
gem "bootsnap", require: false
gem "sassc-rails"
gem "image_processing", "~> 1.2"

# ActivityPub & Federation
gem "httparty"                    # HTTP requests for federation
gem "rsa"                        # RSA key generation for HTTP signatures
gem "json-ld"                    # JSON-LD processing
gem "addressable"                # URI handling
gem "nokogiri"                   # HTML/XML processing

# Authentication & Security
gem "bcrypt", "~> 3.1.7"        # Password hashing
gem "jwt"                        # JWT tokens for OAuth
gem "rack-cors"                  # CORS handling

# Background Jobs
gem "solid_queue"                # Rails 8 solid queue for background jobs

# Utilities
gem "nanoid"                     # Generate short unique IDs
gem "blurhash"                   # Image placeholder generation
gem "mini_magick"                # Image processing
gem "marcel"                     # MIME type detection

group :development, :test do
  gem "debug", platforms: %i[ mri windows ]
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "faker"
  gem "pry-rails"
  gem "rubocop", require: false
  gem "rubocop-rails", require: false
  gem "rubocop-rspec", require: false
  gem "rubocop-performance", require: false
end

group :development do
  gem "web-console"
  gem "listen", "~> 3.3"
  gem "spring"
  gem "annotate"                 # Model annotations
  gem "bullet"                   # N+1 query detection
end
