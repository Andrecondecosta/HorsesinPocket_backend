class Api::V1::CountriesController < ApplicationController
  skip_before_action :authorized, only: [:index]
  def index
    countries = ISO3166::Country.all.map do |c|
      {
        code: c.alpha2,
        name: c.translations['pt'] || c.iso_short_name # ✅ Usando `iso_short_name`
      }
    end

    render json: countries
  end
end
