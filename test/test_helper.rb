# test/test_helper.rb
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "database_cleaner/active_record"

# Nos testes não há credenciais desencriptadas; os tokens JWT precisam de uma chave
unless Rails.application.credentials.secret_key_base
  Rails.application.credentials.define_singleton_method(:secret_key_base) { "chave-so-para-testes" * 4 }
end

class ActiveSupport::TestCase
  # Configuração do database_cleaner
  DatabaseCleaner.strategy = :transaction

  setup do
    DatabaseCleaner.start
  end

  teardown do
    DatabaseCleaner.clean
  end

  # Helper method to parse JSON response
  def json_response
    JSON.parse(response.body)
  end

  # Add more helper methods to be used by all tests here...
end
