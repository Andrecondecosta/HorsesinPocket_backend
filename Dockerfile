# Usando uma imagem Ruby como base
FROM ruby:3.1.2

# Configurar variáveis de ambiente
ENV BUNDLE_PATH=/usr/local/bundle

# Instalar dependências do sistema
RUN apt-get update -qq && \
    apt-get install -y build-essential libpq-dev nodejs libvips42

# Criar diretório de trabalho
WORKDIR /app

# Adicionar o Gemfile e Gemfile.lock
COPY Gemfile Gemfile.lock ./

# Instalar gems e pré-compilar o bootsnap
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

# Adicionar o restante do código da aplicação
COPY . .

# Configurar a porta
EXPOSE 3000

# Comando para iniciar a aplicação
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
