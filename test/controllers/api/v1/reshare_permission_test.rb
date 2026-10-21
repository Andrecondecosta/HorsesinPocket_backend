require "test_helper"

# Cadeia André → Pedro → Miguel: quem partilha decide se quem recebe pode voltar a partilhar
class Api::V1::ResharePermissionTest < ActionDispatch::IntegrationTest
  def create_user(name)
    User.create!(first_name: name, last_name: "Teste", email: "#{name.downcase}-#{SecureRandom.hex(3)}@example.test", password: "password123")
  end

  def auth(user)
    { "Authorization" => "Bearer #{JWT.encode({ user_id: user.id, exp: 1.hour.from_now.to_i }, Rails.application.credentials.secret_key_base)}" }
  end

  # Gera um link (como o botão "Generate Link") e devolve o token
  def share(from, can_reshare:)
    post "/api/v1/horses/#{@horse.id}/share_via_link", params: { can_reshare: can_reshare }, headers: auth(from), as: :json
    assert_includes [200, 201], response.status, response.body
    JSON.parse(response.body)["link"].split("/").last
  end

  def open_link(token, as:)
    get "/api/v1/horses/shared/#{token}", headers: auth(as)
    assert_response :success
  end

  def received_by(user)
    get "/api/v1/received", headers: auth(user)
    JSON.parse(response.body).find { |h| h["id"] == @horse.id }
  end

  setup do
    @andre = create_user("Andre")
    @pedro = create_user("Pedro")
    @miguel = create_user("Miguel")
    @horse = @andre.horses.create!(name: "Zéfiro", age: 2015, height_cm: 1.6, gender: "Stallion", color: "Gray")
  end

  test "sem permissão, quem recebe não pode partilhar" do
    open_link(share(@andre, can_reshare: false), as: @pedro)

    assert_equal false, received_by(@pedro)["can_reshare"]
    get "/api/v1/horses/#{@horse.id}", headers: auth(@pedro)
    assert_equal false, JSON.parse(response.body)["can_share"]

    post "/api/v1/horses/#{@horse.id}/share_via_link", params: { can_reshare: false }, headers: auth(@pedro), as: :json
    assert_response :forbidden
  end

  test "com permissão, o Pedro partilha com o Miguel, que vê 'partilhado por Pedro'" do
    open_link(share(@andre, can_reshare: true), as: @pedro)
    assert_equal true, received_by(@pedro)["can_reshare"]

    open_link(share(@pedro, can_reshare: false), as: @miguel)
    miguel_view = received_by(@miguel)
    assert_equal "Pedro Teste", miguel_view["sender_name"]
    assert_equal false, miguel_view["can_reshare"]
  end

  test "se o André remove o Pedro, o Miguel também perde o acesso" do
    open_link(share(@andre, can_reshare: true), as: @pedro)
    open_link(share(@pedro, can_reshare: false), as: @miguel)

    delete "/api/v1/horses/#{@horse.id}/delete_shares", params: { user_ids: [@pedro.id] }, headers: auth(@andre), as: :json
    assert_response :success

    assert_nil received_by(@pedro)
    assert_nil received_by(@miguel)
  end

  test "a permissão também passa quando o link é usado no login e no registo" do
    post "/api/v1/login", params: { email: @pedro.email, password: "password123", shared_token: share(@andre, can_reshare: true) }, as: :json
    assert_response :success
    assert_equal true, received_by(@pedro)["can_reshare"]

    post "/api/v1/signup", params: { shared_token: share(@andre, can_reshare: true),
                                     user: { first_name: "Novo", last_name: "Teste", email: "novo-#{SecureRandom.hex(3)}@example.test",
                                             password: "password123", password_confirmation: "password123" } }, as: :json
    assert_response :created
    assert UserHorse.find_by(user_id: User.order(:created_at).last.id, horse_id: @horse.id).can_reshare
  end

  test "o dono pode sempre partilhar" do
    get "/api/v1/horses/#{@horse.id}", headers: auth(@andre)
    assert_equal true, JSON.parse(response.body)["can_share"]
  end
end
