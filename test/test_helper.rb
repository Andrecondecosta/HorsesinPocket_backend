# test/test_helper.rb
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
