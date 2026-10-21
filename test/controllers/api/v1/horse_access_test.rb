require "test_helper"

class Api::V1::HorseAccessTest < ActionDispatch::IntegrationTest
  def create_user(name)
    User.create!(first_name: name, last_name: "Teste", email: "#{name.downcase}-#{SecureRandom.hex(3)}@example.test", password: "password123")
  end

  def auth(user)
    { "Authorization" => "Bearer #{JWT.encode({ user_id: user.id, exp: 1.hour.from_now.to_i }, Rails.application.credentials.secret_key_base)}" }
  end

  setup do
    @owner = create_user("Dono")
    @other = create_user("Outro")
    @horse = @owner.horses.create!(name: "Zéfiro", age: 2015, height_cm: 1.6, gender: "Stallion", color: "Gray")
  end

  test "o dono vê e altera o seu cavalo" do
    get "/api/v1/horses/#{@horse.id}", headers: auth(@owner)
    assert_response :success
    put "/api/v1/horses/#{@horse.id}", params: { horse: { name: "Zéfiro II" } }, headers: auth(@owner)
    assert_equal "Zéfiro II", @horse.reload.name
  end

  test "quem não tem nada a ver com o cavalo não o vê" do
    get "/api/v1/horses/#{@horse.id}", headers: auth(@other)
    assert_response :not_found
  end

  %w[revoked pending_approval].each do |status|
    test "com a partilha #{status}, quem recebeu não abre o cavalo pelo endereço" do
      UserHorse.create!(horse: @horse, user: @other, shared_by: @owner.id, status: status)
      get "/api/v1/horses/#{@horse.id}", headers: auth(@other)
      assert_response :not_found
    end
  end

  test "quem recebeu (ativo) vê o cavalo mas não o pode alterar" do
    UserHorse.create!(horse: @horse, user: @other, shared_by: @owner.id, status: "active")
    get "/api/v1/horses/#{@horse.id}", headers: auth(@other)
    assert_response :success

    put "/api/v1/horses/#{@horse.id}", params: { horse: { name: "Roubado" } }, headers: auth(@other)
    assert_response :forbidden
    assert_equal "Zéfiro", @horse.reload.name
  end
end

class Api::V1::AncestorsAccessTest < ActionDispatch::IntegrationTest
  test "só o dono vê e altera o pedigree pela API de ancestrais" do
    owner = User.create!(first_name: "Dono", last_name: "Teste", email: "dono-#{SecureRandom.hex(3)}@example.test", password: "password123")
    other = User.create!(first_name: "Outro", last_name: "Teste", email: "outro-#{SecureRandom.hex(3)}@example.test", password: "password123")
    horse = owner.horses.create!(name: "Zéfiro", age: 2015, height_cm: 1.6, gender: "Stallion", color: "Gray")
    auth = ->(u) { { "Authorization" => "Bearer #{JWT.encode({ user_id: u.id, exp: 1.hour.from_now.to_i }, Rails.application.credentials.secret_key_base)}" } }

    post "/api/v1/horses/#{horse.id}/ancestors", params: { ancestor: { name: "Intruso", relation_type: "father" } }, headers: auth.(other)
    assert_response :not_found
    assert_equal 0, horse.ancestors.count

    post "/api/v1/horses/#{horse.id}/ancestors", params: { ancestor: { name: "Rubi", relation_type: "father" } }, headers: auth.(owner)
    assert_response :created
  end
end
