class AddPlanAndLimitsToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :plan, :string, default: "free" # Plano atual do utilizador
    add_column :users, :used_horses, :integer, default: 0 # Cavalos criados no mês
    add_column :users, :used_transfers, :integer, default: 0 # Transferências feitas
    add_column :users, :subscription_end, :datetime # Data de término do plano premium
  end
end
