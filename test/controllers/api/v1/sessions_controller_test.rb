# test/controllers/api/v1/sessions_controller_test.rb
require "test_helper"

class Api::V1::SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  test "should login with valid credentials" do
    post api_v1_login_url, params: { email: @user.email, password: 'password' }
    assert_response :success
    assert_not_nil json_response['token']
  end

  test "should not login with invalid credentials" do
    post api_v1_login_url, params: { email: 'invalid@example.com', password: 'wrongpassword' }
    assert_response :unauthorized
  end
end
