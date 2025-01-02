# Configuração de Threads
max_threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
min_threads_count = ENV.fetch("RAILS_MIN_THREADS") { 1 }
threads min_threads_count, max_threads_count

# Configuração de Workers
if ENV["RAILS_ENV"] == "production"
  require "concurrent-ruby"
  worker_count = Integer(ENV.fetch("WEB_CONCURRENCY") { Concurrent.physical_processor_count })
  workers worker_count if worker_count > 1
end

# Configuração de Timeout
worker_timeout ENV.fetch("WORKER_TIMEOUT", 60)

# Configuração de Porta e Ambiente
port ENV.fetch("PORT") { 3000 }
environment ENV.fetch("RAILS_ENV") { "development" }

# Configuração de PID
pidfile ENV.fetch("PIDFILE") { "tmp/pids/server.pid" }

# Logs
stdout_redirect(nil, nil, true)

# Cluster
preload_app!

on_worker_boot do
  ActiveRecord::Base.establish_connection if defined?(ActiveRecord)
end

# Plugin de Restart
plugin :tmp_restart
