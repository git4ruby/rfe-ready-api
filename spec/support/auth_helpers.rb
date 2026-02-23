module AuthHelpers
  def authenticated_headers(user)
    token = Warden::JWTAuth::UserEncoder.new.call(user, :user, nil).first
    { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }
  end

  def auth_headers(user)
    authenticated_headers(user)
  end
end
