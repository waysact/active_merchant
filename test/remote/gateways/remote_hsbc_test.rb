require 'test_helper'

class RemoteHsbcTest < Test::Unit::TestCase
  def setup
    @gateway = HsbcGateway.new(fixtures(:hsbc))

    @amount = 100
    @options = {
      merchant_request_identification: SecureRandom.hex(15),
      creditor_reference: 'REDACTED',
      debtor_name: 'REDACTED',
      debtor_bank_code: 'REDACTED',
      account_identification: 'REDACTED',
      creditor_name: 'REDACTED',
      debtor_private_identification: 'REDACTED',
      debtor_private_identification_scheme_name: 'REDACTED',
      debtor_mobile_number: 'REDACTED',
      creditor_bank_code: 'REDACTED',
      creditor_account_identification: 'REDACTED',
    }
  end

  def test_invalid_login
    gateway = HsbcGateway.new(
      client_id: 'test_failure',
      client_secret: 'eruliaf_tset',
      profile_id: 'PC12345678',
      public_key: 'NONE'
    )

    response = gateway.authorize(@amount, @options)
    assert_failure response
    assert_match "wrong client_id or client_secret", response.message
  end

  def test_successful_authorisation
    response = @gateway.authorize(@amount, @options)
    assert_success response
    assert_match "00", response.message["ProcessResult"]["ResponseCode"]

    otp_options = {}
    otp_options[:mandate_identification] = response.message["MandateIdentification"]
    otp_options[:otp_identification_number] = response.message["OtpIdentificationNumber"]
    puts "Enter OTP password:"
    otp_password = STDIN.gets
    otp_options[:otp_password] = otp_password.chomp
    otp_response = @gateway.authorize_confirmation(@options.merge(otp_options))
    assert_success otp_response
    assert_match "00", otp_response.message["ProcessResult"]["ResponseCode"]
  end

  def test_successful_otp_regeneration_authorisation
    response = @gateway.authorize(@amount, @options)
    assert_success response
    assert_match "00", response.message["ProcessResult"]["ResponseCode"]

    @options.merge!(mandate_identification: response.message["MandateIdentification"])
    otp_regeneration_request = @gateway.authorize_otp_regeneration(@options)
    assert_success otp_regeneration_request
    assert_match "00", otp_regeneration_request.message["ProcessResult"]["ResponseCode"]

    @options.merge!(otp_identification_number: otp_regeneration_request.message["OtpIdentificationNumber"])
    puts "Enter the *SECOND* OTP password you were sent:"
    otp_password = STDIN.gets
    @options.merge!(otp_password: otp_password.chomp)
    otp_response = @gateway.authorize_confirmation(@options)
    assert_success otp_response
    assert_match "00", otp_response.message["ProcessResult"]["ResponseCode"]
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.authorize(@amount, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@gateway.options[:client_id], transcript)
    assert_scrubbed(@gateway.options[:client_secret], transcript)
  end
end
