class HomeController < ApplicationController
  def Index
    render json: {message: 'bem vindo a , API de teste'}
  end
end
