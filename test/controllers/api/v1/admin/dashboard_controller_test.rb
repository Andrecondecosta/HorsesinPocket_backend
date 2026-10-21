require "test_helper"

class Api::V1::Admin::DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(email: "admin-#{SecureRandom.hex(4)}@example.test", password: "password123",
                          first_name: "Ana", last_name: "Admin", admin: true,
                          stripe_customer_id: "cus_teste")
    @token = JWT.encode({ user_id: @admin.id, exp: 1.hour.from_now.to_i }, Rails.application.credentials.secret_key_base)
  end

  # O admin tem stripe_customer_id: se a serialização ainda chamasse o Stripe, o pedido
  # falhava (não há chave válida nos testes) em vez de responder 200
  test "lista utilizadores só com os campos do painel e sem chamar o Stripe" do
    get "/api/v1/admin/users", headers: { "Authorization" => "Bearer #{@token}" }

    assert_response :success
    user = JSON.parse(response.body).find { |u| u["id"] == @admin.id }
    assert_equal %w[admin country created_at email first_name id last_name], user.keys.sort
  end

  test "recusa quem não é administrador" do
    @admin.update!(admin: false)
    get "/api/v1/admin/users", headers: { "Authorization" => "Bearer #{@token}" }
    assert_response :forbidden
  end
end
