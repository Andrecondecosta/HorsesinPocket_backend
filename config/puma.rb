# Número de workers (threads paralelas por processo)
workers ENV.fetch("WEB_CONCURRENCY") { 2 }

# Configuração do número de threads mínimo e máximo
threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
threads threads_count, threads_count

# Porta padrão para a aplicação
port ENV.fetch("PORT") { 3000 }

# Ambiente de execução (development, production, etc.)
environment ENV.fetch("RAILS_ENV") { "development" }

# Pré-carrega a aplicação antes de forkar os workers
preload_app!

# Configuração do ActiveRecord em cada worker
on_worker_boot do
  ActiveRecord::Base.establish_connection if defined?(ActiveRecord)
end

# Permite reiniciar o Puma com o comando `rails restart`
plugin :tmp_restart
