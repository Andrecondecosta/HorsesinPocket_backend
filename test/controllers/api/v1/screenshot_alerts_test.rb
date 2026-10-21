require "test_helper"

class Api::V1::ScreenshotAlertsTest < ActionDispatch::IntegrationTest
  test "os alertas trazem o nome de quem tirou a captura" do
    owner = User.create!(first_name: "Dono", last_name: "Teste", email: "dono-#{SecureRandom.hex(3)}@example.test", password: "password123")
    viewer = User.create!(first_name: "Pedro", last_name: "Silva", email: "pedro-#{SecureRandom.hex(3)}@example.test", password: "password123")
    horse = owner.horses.create!(name: "Zéfiro", age: 2015, height_cm: 1.6, gender: "Stallion", color: "Gray")
    user_horse = UserHorse.create!(horse: horse, user: viewer, shared_by: owner.id, status: "pending_approval")
    token = JWT.encode({ user_id: owner.id, exp: 1.hour.from_now.to_i }, Rails.application.credentials.secret_key_base)

    get "/api/v1/screenshot_alerts", headers: { "Authorization" => "Bearer #{token}" }

    assert_response :success
    group = JSON.parse(response.body)["screenshot_alerts"].find { |g| g["horse_id"] == horse.id }
    assert_equal [{ "user_horse_id" => user_horse.id, "user_name" => "Pedro Silva" }], group["alerts"]
  end
end
