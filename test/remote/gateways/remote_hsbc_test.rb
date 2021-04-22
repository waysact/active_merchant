require 'test_helper'

class RemoteHsbcTest < Test::Unit::TestCase
  def setup
    @gateway = HsbcGateway.new(fixtures(:hsbc))

    @amount = 100
    @direct_debit = 'REDACTED'
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

    response = gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_match "wrong client_id or client_secret", response.message
  end

  def test_successful_authorisation
    response = @gateway.authorize(@amount, @direct_debit, @options)
    assert_success response
    assert_match "wrong client_id or client_secret", response.message
  end

  def test_dump_transcript
    # This test will run a purchase transaction on your gateway
    # and dump a transcript of the HTTP conversation so that
    # you can use that transcript as a reference while
    # implementing your scrubbing logic.  You can delete
    # this helper after completing your scrub implementation.
    dump_transcript_and_fail(@gateway, @amount, @credit_card, @options)
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:password], transcript)
  end

end
