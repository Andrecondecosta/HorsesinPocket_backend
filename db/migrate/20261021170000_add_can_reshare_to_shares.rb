# Permissão para quem recebe um cavalo o voltar a partilhar. Dada por quem partilha,
# link a link; as partilhas que já existem ficam sem permissão.
class AddCanReshareToShares < ActiveRecord::Migration[7.1]
  def change
    add_column :shared_links, :can_reshare, :boolean, default: false, null: false
    add_column :user_horses, :can_reshare, :boolean, default: false, null: false
  end
end
