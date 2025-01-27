# app/controllers/stripe_controller.rb
class StripeController < ApplicationController
  def create_customer
    customer = Stripe::Customer.create({
      email: current_user.email,
      description: "Cliente do sistema XYZ",
    })

    current_user.update!(stripe_customer_id: customer.id)

    render json: { message: 'Cliente Stripe criado com sucesso', customer: customer }, status: :ok
  end
end
