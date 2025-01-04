# Usa uma imagem base Ruby
FROM ruby:3.2

# Define o diretório de trabalho
WORKDIR /app

# Instala dependências do sistema
RUN apt-get update -qq && apt-get install -y build-essential libpq-dev nodejs postgresql-client

# Copia o Gemfile e o Gemfile.lock
COPY Gemfile Gemfile.lock ./

# Instala gems
RUN bundle install

# Copia o restante da aplicação
COPY . .

# Configura o ambiente de produção (podes ajustar conforme necessário)
ENV RAILS_ENV=production


# Configura a porta
EXPOSE 3000

# Comando para iniciar o servidor
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
