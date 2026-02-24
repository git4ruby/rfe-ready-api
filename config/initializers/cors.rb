Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV.fetch("FRONTEND_URL", "http://localhost:5173")

    resource "*",
      headers: :any,
      methods: [ :get, :post, :put, :patch, :delete, :options, :head ],
      expose: [ "Authorization", "Content-Disposition", "X-RateLimit-Limit", "X-RateLimit-Remaining", "X-RateLimit-Reset" ],
      max_age: 600
  end
end
