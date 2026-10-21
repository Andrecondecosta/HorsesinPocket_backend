require "test_helper"

# O HorseHub é gratuito: nenhuma conta tem limites, seja qual for o plano guardado
class UserLimitsTest < ActiveSupport::TestCase
  test "qualquer plano fica sem limites de cavalos e partilhas" do
    %w[Basic Plus Premium Ultimate free].each do |plan|
      user = User.create!(first_name: "Ana", last_name: plan, email: "#{plan.downcase}-#{SecureRandom.hex(3)}@example.test",
                          password: "password123", plan: plan)
      assert_equal 999_999, user.max_horses, plan
      assert_equal 999_999, user.max_shares, plan
    end
  end

  test "uma conta despromovida para Basic continua sem limites" do
    user = User.create!(first_name: "Ana", last_name: "Silva", email: "ana-#{SecureRandom.hex(3)}@example.test",
                        password: "password123", plan: "Ultimate", subscription_end: 1.day.ago)
    user.check_and_downgrade_plan
    assert_equal "Basic", user.reload.plan
    assert_equal 999_999, user.max_horses
  end
end
