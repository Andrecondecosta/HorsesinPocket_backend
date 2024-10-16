# test/controllers/api/v1/registrations_controller_test.rb
require "test_helper"

class Api::V1::RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "should register with valid data" do
    post api_v1_signup_url, params: { user: { email: 'newuser@example.com', password: 'password', password_confirmation: 'password' } }
    assert_response :created
    assert_not_nil json_response['token']
  end

  test "should not register with invalid data" do
    post api_v1_signup_url, params: { user: { email: 'invalid', password: 'short', password_confirmation: 'short' } }
    assert_response :unprocessable_entity
  end
end
