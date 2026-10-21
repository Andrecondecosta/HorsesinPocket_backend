# test/controllers/api/v1/registrations_controller_test.rb
require "test_helper"

class Api::V1::RegistrationsControllerTest < ActionDispatch::IntegrationTest
  def signup_params(overrides = {})
    { user: { first_name: "Ana", last_name: "Silva", email: "nova-#{SecureRandom.hex(4)}@example.test",
              password: "password123", password_confirmation: "password123" }.merge(overrides) }
  end

  # Sem chave do Stripe nos testes: se o registo ainda o chamasse, respondia 503
  test "regista sem Stripe, no plano sem limites" do
    post api_v1_signup_url, params: signup_params
    assert_response :created
    assert_not_nil json_response["token"]

    user = User.order(:created_at).last
    assert_equal "Ultimate", user.plan
    assert_nil user.stripe_customer_id
    assert_nil user.subscription_end
    assert_equal 999_999, user.max_horses
  end

  test "regista com o token de partilha e o cavalo fica na conta nova" do
    owner = User.create!(first_name: "Dono", last_name: "Teste", email: "dono-#{SecureRandom.hex(4)}@example.test", password: "password123")
    horse = owner.horses.create!(name: "Zéfiro", age: 2015, height_cm: 1.6, gender: "Stallion", color: "Gray")
    link = SharedLink.create!(token: SecureRandom.hex(8), horse: horse, shared_by: owner.id, status: "active")

    post api_v1_signup_url, params: signup_params.merge(shared_token: link.token)
    assert_response :created

    user = User.order(:created_at).last
    assert UserHorse.exists?(user_id: user.id, horse_id: horse.id)
  end

  test "não regista com dados inválidos" do
    post api_v1_signup_url, params: { user: { email: "invalid", password: "short", password_confirmation: "short" } }
    assert_response :unprocessable_entity
  end

  test "atualizar o perfil devolve só os campos do perfil, sem chamar o Stripe" do
    user = User.create!(first_name: "Ana", last_name: "Silva", email: "ana-#{SecureRandom.hex(4)}@example.test",
                        password: "password123", stripe_customer_id: "cus_teste")
    token = JWT.encode({ user_id: user.id, exp: 1.hour.from_now.to_i }, Rails.application.credentials.secret_key_base)

    put "/api/v1/update", params: { user: { country: "Spain" } }, headers: { "Authorization" => "Bearer #{token}" }

    assert_response :success
    assert_equal "Spain", json_response["country"]
    assert_not_includes json_response.keys, "stripe_customer_id"
  end
end
