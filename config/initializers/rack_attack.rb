class Rack::Attack
  # Throttle API requests by IP (300 requests per 5 minutes)
  throttle("api/ip", limit: 300, period: 5.minutes) do |req|
    req.ip if req.path.start_with?("/api/")
  end

  # Throttle login attempts by IP (5 attempts per 20 seconds)
  throttle("logins/ip", limit: 5, period: 20.seconds) do |req|
    req.ip if req.path == "/api/v1/users/sign_in" && req.post?
  end

  # Throttle login attempts by email (5 attempts per 2 minutes)
  throttle("logins/email", limit: 5, period: 2.minutes) do |req|
    if req.path == "/api/v1/users/sign_in" && req.post?
      begin
        body = req.body&.read
        req.body&.rewind
        parsed = body.present? ? JSON.parse(body) : {}
        parsed.dig("user", "email")&.downcase&.strip
      rescue JSON::ParserError
        nil
      end
    end
  end

  # Add rate limit headers to throttled responses
  self.throttled_responder = lambda do |req|
    match_data = req.env["rack.attack.match_data"] || {}
    retry_after = match_data[:period]
    [
      429,
      {
        "Content-Type" => "application/json",
        "Retry-After" => retry_after.to_s,
        "X-RateLimit-Limit" => match_data[:limit].to_s,
        "X-RateLimit-Remaining" => "0",
        "X-RateLimit-Reset" => (Time.now + retry_after.to_i).to_i.to_s
      },
      [ { error: "Rate limit exceeded. Try again in #{retry_after} seconds." }.to_json ]
    ]
  end

  # Expose rate limit headers on successful API responses
  ActiveSupport::Notifications.subscribe(/rack_attack/) do |_name, _start, _finish, _id, payload|
    # Headers are added via middleware below
  end
end

# Middleware to add rate limit headers to all API responses
class RateLimitHeaders
  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, body = @app.call(env)

    if env["PATH_INFO"]&.start_with?("/api/")
      match_data = env["rack.attack.throttle_data"]&.dig("api/ip")
      if match_data
        headers["X-RateLimit-Limit"] = match_data[:limit].to_s
        headers["X-RateLimit-Remaining"] = [ match_data[:limit] - match_data[:count], 0 ].max.to_s
        headers["X-RateLimit-Reset"] = (match_data[:epoch_time] + match_data[:period]).to_i.to_s
      end
    end

    [ status, headers, body ]
  end
end

Rails.application.config.middleware.insert_after Rack::Attack, RateLimitHeaders
