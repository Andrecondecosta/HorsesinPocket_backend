require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot. This eager loads most of Rails and
  # your application in memory, allowing both threaded web servers
  # and those relying on copy on write to perform better.
  # Rake tasks automatically ignore this option for performance.
  config.eager_load = true

  # Full error reports are disabled and caching is turned on.
  config.consider_all_requests_local = false

  # Ensures that a master key has been made available.
  config.require_master_key = true

  # Disable serving static files from `public/`, relying on NGINX/Apache to do so instead.
  # Enable static file serving if `RAILS_SERVE_STATIC_FILES` is set.
  config.public_file_server.enabled = ENV['RAILS_SERVE_STATIC_FILES'].present?

  # Compress JavaScripts and CSS
  config.assets.js_compressor = :uglifier
  config.assets.css_compressor = :sass

  # Do not fall back to assets pipeline if a precompiled asset is missed.
  config.assets.compile = false

  # Store uploaded files on the configured storage service.
  config.active_storage.service = :cloudinary

  # Force all access to the app over SSL and use secure cookies.
  config.force_ssl = ENV['RAILS_FORCE_SSL'] == 'true'

  # Use the lowest log level to ensure availability of diagnostic information
  # when problems arise.
  config.log_level = :info

  # Prepend all log lines with the following tags.
  config.log_tags = [:request_id]

  # Use a different cache store in production.
  # config.cache_store = :mem_cache_store

  # Use a real queuing backend for Active Job.
  config.active_job.queue_adapter = :async

  # Action Mailer configuration
  config.action_mailer.perform_caching = false
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.default_url_options = { host: ENV['APP_HOST'], protocol: 'https' }
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address: 'smtp.gmail.com',
    port: 587,
    domain: 'horsesinpocket-backend-2.onrender.com',
    user_name: ENV['EMAIL_USER'],
    password: ENV['EMAIL_PASSWORD'],
    authentication: 'plain',
    enable_starttls_auto: true
  }

  # Enable locale fallbacks for I18n.
  config.i18n.fallbacks = true

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Precompile assets before runtime
  config.assets.digest = true

  # Add allowed hosts for production.
  config.hosts << "horsesinpocket-backend-2.onrender.com"
  config.hosts << "horsesinpocket-frontend.onrender.com"
  config.hosts << "localhost"
  config.hosts << "localhost:3000"

  # Skip DNS rebinding protection for specific paths.
  config.host_authorization = {
    exclude: ->(request) {
      request.path == "/up" || request.host == "horsesinpocket-frontend.onrender.com"
    }
  }

  # Log to STDOUT
  config.logger = ActiveSupport::Logger.new(STDOUT)
  config.log_formatter = ::Logger::Formatter.new
end
