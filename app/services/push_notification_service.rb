require 'net/http'
require 'uri'
require 'json'
require 'openssl'
require 'jwt'

class PushNotificationService
  APNS_URL = ENV['APNS_ENV'] == 'production' ?
    'https://api.push.apple.com' :
    'https://api.sandbox.push.apple.com'

  # Send to all active devices of a user
  def self.send_to_user(user, title:, body:, data: {})
    return unless user.present?

    tokens = DeviceToken.where(user_id: user.id, active: true)
    return if tokens.empty?

    tokens.each do |device_token|
      response = send_notification(device_token.token, title: title, body: body)

      if response.nil? || !response.is_a?(Net::HTTPSuccess)
        Rails.logger.warn "[PushNotifications] Deactivating invalid token for user #{user.id}"
        device_token.update(active: false)
      else
        device_token.touch_last_used
      end
    end
  end

  # Send to a single device token
  def self.send_notification(device_token, title:, body:)
    new.send_notification(device_token, title: title, body: body)
  end

  def send_notification(device_token, title:, body:)
    token = generate_jwt

    uri = URI("#{APNS_URL}/3/device/#{device_token}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri.path)
    request['authorization'] = "bearer #{token}"
    request['apns-topic']    = ENV['APNS_BUNDLE_ID']
    request['content-type']  = 'application/json'

    request.body = {
      aps: {
        alert: { title: title, body: body },
        sound: 'default'
      }
    }.to_json

    response = http.request(request)
    Rails.logger.info "[PushNotifications] status=#{response.code} body=#{response.body}"
    response

  rescue => e
    Rails.logger.error "[PushNotifications] Error: #{e.message}"
    nil
  end

  private

  def generate_jwt
    private_key = ENV['APNS_PRIVATE_KEY']
    raise 'APNS_PRIVATE_KEY missing' if private_key.blank?

    private_key = private_key.gsub('\n', "\n")
    ecdsa_key   = OpenSSL::PKey::EC.new(private_key)

    JWT.encode(
      { iss: ENV['APNS_TEAM_ID'], iat: Time.now.to_i },
      ecdsa_key,
      'ES256',
      { kid: ENV['APNS_KEY_ID'] }
    )
  end
end
