require "test_helper"

class ScreenshotsControllerTest < ActionDispatch::IntegrationTest
  test "should get create" do
    get screenshots_create_url
    assert_response :success
  end
end
