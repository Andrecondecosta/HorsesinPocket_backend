Stripe.api_key = ENV['STRIPE_API_KEY']

Rails.logger.info("Chave do Stripe configurada: #{Stripe.api_key}")
