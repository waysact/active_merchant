require 'test_helper'

class RemoteEngagingNetworksTest < Test::Unit::TestCase
  def setup
    @gateway = EngagingNetworksGateway.new(fixtures(:engaging_networks))

    @amount = 100
    @credit_card = credit_card('4000100011112224')

    # Use the same approach as WorldPay, as EngagingNetworks uses Vantiv
    # under the hood
    @declined_card =
      credit_card('4111111111111111', first_name: nil, last_name: 'REFUSED')
    @check = check(account_type: 'checking')
    @options = {
      billing_address:
        address(city: 'Hollywood', state: 'CA', zip: '90210', country: 'US'),
      description: 'Evergiving Donation',
      email_label: 'EVG',
      customer: {
        dob: '1981-01-01',
        first_name: 'Longbob',
        last_name: 'Longsen',
        mobile_number: address[:phone],
        home_home: address[:phone]
      },
      page_id: 78_936,
      appealcode: 'BBCRMSOURCECODE',
      txn7: "[EVG][123][#{SecureRandom.hex(15)}]"
    }
  end

  def test_successful_authenticate
    response = @gateway.authenticate
    assert_success response
    assert_match /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/,
                 response.message
  end

  def test_failed_login
    gateway = EngagingNetworksGateway.new(api_key: 'foobar')
    response = gateway.authenticate
    assert_failure response
    assert_equal 'Invalid credentials', response.message
  end

  def test_successful_donation
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'SUCCESS|CREDIT_SINGLE', response.message
  end

  def test_successful_donation_with_more_options
    options = {
      billing_address:
        address(city: 'Hollywood', state: 'CA', zip: '90210', country: 'US'),
      description: 'Evergiving Donation',
      email: 'test@example.com',
      customer: {
        dob: '1981-01-01',
        first_name: 'Longbob',
        last_name: 'Longsen',
        mobile_number: address[:phone],
        home_home: address[:phone]
      },
      stay_informed_nature_news: 'Y',
      get_involved_advocacy: 'Y',
      get_involved_membership: 'Y',
      get_involved_events: 'Y',
      get_involved_volunteer: 'Y',
      page_id: 78_936,
      appealcode: 'BBCRMSOURCECODE',
      txn7: "[EVG][123][#{SecureRandom.hex(15)}]"
    }
    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'SUCCESS|CREDIT_SINGLE', response.message
  end

  def test_successful_recurring_donation
    @options.merge!(recurrfreq: 'QUARTERLY')
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'SUCCESS|CREDIT_RECURRING', response.message
  end

  def test_successful_ach_donation
    response = @gateway.purchase(@amount, @check, @options)
    assert_success response
    assert_equal 'SUCCESS|CHECK', response.message
  end

  def test_successful_ach_recurring_donation
    @options.merge!(recurrfreq: 'QUARTERLY')

    response = @gateway.purchase(@amount, @check, @options)
    assert_success response
    assert_equal 'SUCCESS|RECUR_UNMANAGED', response.message
  end

  def test_failed_purchase
    @options[:customer][:first_name] = @declined_card.first_name
    @options[:customer][:last_name] = @declined_card.last_name
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'First Name is required for the Vantiv Gateway but was not passed in.',
                 response.message
  end

  def test_transcript_scrubbing
    transcript =
      capture_transcript(@gateway) do
        @gateway.purchase(@amount, @credit_card, @options)
      end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@gateway.options[:api_key], transcript)
  end
end
