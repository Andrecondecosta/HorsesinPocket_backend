class Api::V1::AncestorsController < ApplicationController
  before_action :set_horse

      # Lista todos os ancestrais de um cavalo
      def index
        ancestors = @horse.ancestors
        render json: ancestors
      end

      # Cria um novo ancestral
      def create
        ancestor = @horse.ancestors.build(ancestor_params)
        if ancestor.save
          render json: ancestor, status: :created
        else
          render json: ancestor.errors, status: :unprocessable_entity
        end
      end

      # Atualiza um ancestral existente
      def update
        ancestor = @horse.ancestors.find(params[:id])
        if ancestor.update(ancestor_params)
          render json: ancestor
        else
          render json: ancestor.errors, status: :unprocessable_entity
        end
      end

      # Exclui um ancestral
      def destroy
        ancestor = @horse.ancestors.find(params[:id])
        ancestor.destroy
        head :no_content
      end

      private

      # Define o cavalo com base no parâmetro :horse_id
      def set_horse
        @horse = Horse.find(params[:horse_id])
      end

      # Permite apenas os parâmetros permitidos para ancestrais
      def ancestor_params
        params.require(:ancestor).permit(:name, :breed, :breeder, :relation_type)
      end
end
