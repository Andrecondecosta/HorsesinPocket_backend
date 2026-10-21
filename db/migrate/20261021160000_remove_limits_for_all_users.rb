# O HorseHub passou a ser gratuito: todas as contas ficam sem limites de cavalos e partilhas.
# Os limites estão guardados em cada utilizador (max_horses/max_shares), por isso é preciso
# atualizá-los; o plano de cada conta não é alterado.
class RemoveLimitsForAllUsers < ActiveRecord::Migration[7.1]
  UNLIMITED = 999_999

  def up
    execute "UPDATE users SET max_horses = #{UNLIMITED}, max_shares = #{UNLIMITED}"
  end

  def down
    # Sem volta automática: os limites antigos dependiam do plano de cada conta.
    # Se for preciso repor, basta voltar a guardar cada utilizador com os PLAN_LIMITS antigos.
  end
end
