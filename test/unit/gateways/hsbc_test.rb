require 'test_helper'

class HsbcTest < Test::Unit::TestCase
  def setup
    @gateway = HsbcGateway.new(fixtures(:hsbc))

    @amount = 100
    @direct_debit = '123456789012'
    @options = {
      merchant_request_identification: '132c073c3cb81dd2fa471c7511a883',
      creditor_reference: 'CREDITOR_REFERENCE',
      debtor_name: 'CUSTOMER CLIENT',
      debtor_bank_code: '004',
      account_identification: '123456789012',
      creditor_name: 'Foo Bar',
      debtor_private_identification: 'R000000',
      debtor_private_identification_scheme_name: 'NIDN',
      debtor_mobile_number: '+61-000000000',
      creditor_bank_code: '004',
      creditor_account_identification: '000000000001',
    }
  end

  def test_successful_authorisation
    @gateway.expects(:ssl_post).returns(successful_authorisation_response)

    response = @gateway.authorize(@amount, @direct_debit, @options)
    assert_success response

    assert_equal 'D2002091N014', response.authorization
    assert response.test?
  end

  def test_failed_authorisation
    pend("Pending implementation of failed authorisation test")
  end

  def test_scrub
    pend("Pending implementation of scrubbing test")
  end

  private

  def successful_authorisation_response
    '{"ResponseBase64": "LS0tLS1CRUdJTiBQR1AgTUVTU0FHRS0tLS0tCgpoSXdETVl6a0NCNE44MmdCQS85TzBXbWQwS25ZNzVhZWJBZUFrclNIcUc2TDJBWXpmMWRSNWdEOUtuSHIzUFZCCnVyZmZGZUdlcWZTdHIyUVk4aE5aMkFseGpBdE8zdUwwR3NodGExZnkxT3dmemd4d1cyQmtaRm9xSFVuSHlXOTIKYXNJNlFuVkUyRGZHWElrWmoxdWVXRUtlbitOam05STgyelJNYjU0dmpoNGF6MTdhZ3ZlZjdsVUtoS0VTUU5MQQo0Z0hGVFdvNGhob2k1czgwbm1kQWM3YmZaMmJKK1BtOWpjcVJLcEIzK2JaSmhjbzFxaU1uM0E2bmVqZndVd3FYCmJxOFZaUjMrQjB3T2FhY1FrUHdTREJEbkNxKzhvUjZ5Z1prUHpLYzN2TGQ4ZGtScTZKYUREMzl2Qlp6amdnenQKZEpIenZsR1BoYjF1VVBhRHl1MlhyVkZPalhENGV4bjJqSXR6ditqNmpSb0dnM3Z4YU96akVsdWpRMGMyQ3NjKwp3bStmbEFBSEd1bGlJbkxrWEQydUxLQkNxOFJ3ektjc1lLbmljOGluQXpiSlQzM3RyNVdTWmdGcWpPakxIaWtiCnZGeVpEQ1lsMzRzMDM4dGlqaDErVC95akJlaUpmZjB6MjFRS2NVbGZtdU9JcEs0OGJPSkE5bDlWcmhhaFVYYU4Kclprck9JRU1USk55SmsyRi82S2ZnL3lwbWN0VnM3ZzRCMVR6Q0VDZ0tHcWxPWlYrRWhTcndiSXpwSGlTaDk1dApReWxLdm4wK1RZWkVVQWdVc3hnU2RUTllEcVBoZGkzYSt6SVBSMVVIeHhBT0prK3hrSW56T0VvYVp2Qm53bzN6ClB1UDNUQnYranlPN2kwVWYxZ1FyNnM0bEFMQ29jWWdabnNqRDRIb0VrZVMvRTNTaThOa2F4NTkzaFBXQ09hQmIKTTJ0eEYrOTdKWHVxUzlXbmRyKzh2MGlycGVDWU5seTU4bUZjSTFMdmJVa3ZGNWs9Cj1NR2RxCi0tLS0tRU5EIFBHUCBNRVNTQUdFLS0tLS0K"}'
  end

  def failed_authorize_response
  end
end
