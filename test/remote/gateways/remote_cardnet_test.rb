require 'test_helper'

class RemoteCardnetTest < Test::Unit::TestCase
  def setup
    @gateway = CardnetGateway.new(fixtures(:cardnet))

    @amount = 100
    @credit_card = credit_card('4000100011112224')
    @declined_card = credit_card('4000300011112220')
    @options = {
      billing_address: address,
      description: 'Store Purchase',
      token: SecureRandom.alphanumeric(10),
      reference: SecureRandom.uuid,
      invoice: SecureRandom.alphanumeric(10),
      ip: '1.1.1.1'
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)

    assert_success response
    assert_equal 'Transaction Approved', response.message
    assert_match /\d{6}/, response.authorization
  end

  def test_failed_purchase
    response = @gateway.purchase(0, @declined_card, @options)
    assert_failure response
    assert_equal 'amount: must be greater than 0', response.message
  end

  def test_successful_authorize
    auth = @gateway.authorize
    assert_success auth

    assert_equal auth.authorization.length, 32
  end

  def test_transcript_scrubbing
    transcript =
      capture_transcript(@gateway) do
        @gateway.purchase(@amount, @credit_card, @options)
      end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:merchant_id], transcript)
    assert_scrubbed(@gateway.options[:terminal_id], transcript)
  end
end
