require "test_helper"

class Api::V1::ReceivedHorsesTest < ActionDispatch::IntegrationTest
  def create_user(name)
    User.create!(first_name: name, last_name: "Teste", email: "#{name.downcase}-#{SecureRandom.hex(3)}@example.test", password: "password123")
  end

  def token_for(user)
    JWT.encode({ user_id: user.id, exp: 1.hour.from_now.to_i }, Rails.application.credentials.secret_key_base)
  end

  setup do
    @owner = create_user("Dono")
    @recipient = create_user("Recetor")
    @horse = @owner.horses.create!(name: "Zéfiro", age: 2015, height_cm: 1.6, gender: "Stallion", color: "Gray")
  end

  def received
    get "/api/v1/received", headers: { "Authorization" => "Bearer #{token_for(@recipient)}" }
    assert_response :success
    JSON.parse(response.body).find { |h| h["id"] == @horse.id }
  end

  test "mostra o nome de quem partilhou" do
    sharer = create_user("Partilhou")
    UserHorse.create!(horse: @horse, user: @recipient, shared_by: sharer.id)
    assert_equal "Partilhou Teste", received["sender_name"]
  end

  test "sem remetente registado, mostra o dono do cavalo em vez de Desconhecido" do
    UserHorse.create!(horse: @horse, user: @recipient, shared_by: nil)
    assert_equal "Dono Teste", received["sender_name"]
  end

  test "registo com link sem remetente guarda o dono do cavalo como quem partilhou" do
    link = SharedLink.create!(token: SecureRandom.hex(8), horse: @horse, shared_by: nil, status: "active")
    post api_v1_signup_url, params: { shared_token: link.token,
                                      user: { first_name: "Novo", last_name: "Teste", email: "novo-#{SecureRandom.hex(3)}@example.test",
                                              password: "password123", password_confirmation: "password123" } }
    assert_response :created
    new_user = User.order(:created_at).last
    assert_equal @owner.id, UserHorse.find_by(user_id: new_user.id, horse_id: @horse.id).shared_by
  end
end
