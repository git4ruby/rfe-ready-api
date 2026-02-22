class Api::V1::TwoFactorController < Api::V1::BaseController
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  # POST /api/v1/two_factor/setup
  # Generates a new OTP secret and returns the provisioning URI + QR code
  def setup
    secret = ROTP::Base32.random
    current_user.update!(otp_secret: secret)

    totp = ROTP::TOTP.new(secret, issuer: "RFE Ready")
    uri = totp.provisioning_uri(current_user.email)

    qrcode = RQRCode::QRCode.new(uri)
    svg = qrcode.as_svg(
      color: "000",
      shape_rendering: "crispEdges",
      module_size: 4,
      standalone: true,
      use_path: true
    )

    render json: {
      data: {
        secret: secret,
        provisioning_uri: uri,
        qr_svg: svg
      }
    }
  end

  # POST /api/v1/two_factor/verify
  # Verifies the TOTP code and enables 2FA
  def verify
    totp = ROTP::TOTP.new(current_user.otp_secret, issuer: "RFE Ready")

    unless totp.verify(params[:code], drift_behind: 15, drift_ahead: 15)
      render json: { error: "Invalid verification code. Please try again." }, status: :unprocessable_entity
      return
    end

    # Generate backup codes
    backup_codes = Array.new(8) { SecureRandom.hex(4).upcase }
    current_user.update!(
      otp_required_for_login: true,
      otp_backup_codes: backup_codes
    )

    render json: {
      data: {
        enabled: true,
        backup_codes: backup_codes
      }
    }
  end

  # DELETE /api/v1/two_factor
  # Disables 2FA (requires current password and TOTP code)
  def disable
    unless current_user.valid_password?(params[:password])
      render json: { error: "Current password is incorrect." }, status: :unprocessable_entity
      return
    end

    totp = ROTP::TOTP.new(current_user.otp_secret, issuer: "RFE Ready")
    unless totp.verify(params[:code], drift_behind: 15, drift_ahead: 15)
      render json: { error: "Invalid verification code." }, status: :unprocessable_entity
      return
    end

    current_user.update!(
      otp_required_for_login: false,
      otp_secret: nil,
      otp_backup_codes: []
    )

    render json: { data: { enabled: false } }
  end

  # POST /api/v1/two_factor/validate
  # Validates TOTP code during login (called after initial auth)
  def validate
    unless current_user.otp_secret.present?
      render json: { error: "2FA is not enabled." }, status: :unprocessable_entity
      return
    end

    totp = ROTP::TOTP.new(current_user.otp_secret, issuer: "RFE Ready")
    code = params[:code].to_s.strip

    # Check TOTP code
    if totp.verify(code, drift_behind: 15, drift_ahead: 15)
      render json: { data: { valid: true } }
      return
    end

    # Check backup codes
    if current_user.otp_backup_codes.include?(code)
      remaining = current_user.otp_backup_codes - [code]
      current_user.update!(otp_backup_codes: remaining)
      render json: { data: { valid: true, backup_code_used: true, remaining_backup_codes: remaining.size } }
      return
    end

    render json: { error: "Invalid code. Please try again." }, status: :unprocessable_entity
  end
end
