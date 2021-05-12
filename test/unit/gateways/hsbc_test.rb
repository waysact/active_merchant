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
    assert_equal '649', response.message['OtpIdentificationNumber']
    assert response.test?
  end

  def test_failed_authorisation
    @gateway.expects(:ssl_post).returns(failed_authorisation_response)

    response = @gateway.authorize(@amount, @direct_debit, @options)
    assert_failure response
    assert_equal 'RJCT', response.error_code
  end

  def test_successful_authorize_confirmation
    @gateway.expects(:ssl_post).returns(successful_authorize_confirmation_response)

    otp_options = {
      mandate_identification: 'D21051276217',
      otp_identification_number: '863',
      otp_password: '123456'
    }
    response = @gateway.authorize_confirmation(@options.merge(otp_options))

    assert_success response
    assert_equal '00', response.message["ProcessResult"]["ResponseCode"]
    assert response.test?
  end

  def test_failed_authorize_confirmation
    @gateway.expects(:ssl_post).returns(failed_authorize_confirmation_response)

    otp_options = {
      mandate_identification: 'D21051276268',
      otp_identification_number: '380',
      otp_password: '654321'
    }
    response = @gateway.authorize_confirmation(@options.merge(otp_options))

    assert_failure response
    assert_equal 'RJCT', response.error_code
    assert response.test?
  end

  def test_successful_authorize_otp_regeneration
    @gateway.expects(:ssl_post).returns(successful_authorize_otp_regeneration)

    response = @gateway.authorize_otp_regeneration(
      @options.merge(mandate_identification: 'D21051276217')
    )

    assert_success response
    assert_equal '00', response.message['ProcessResult']['ResponseCode']
    assert_equal '123', response.message['OtpIdentificationNumber']
    assert response.test?
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def successful_authorisation_response
    # Encrypted and base64 encoded payload of:
    #
    # {
    #   "ProcessResult": {
    #     "ResponseCode": "00",
    #     "RejectReasonList": null
    #   },
    #   "MandateIdentification": "D2002091N014",
    #   "OtpIdentificationNumber": "649",
    #   "MobileNumber": "861501*******",
    #   "MandateStatus": "PDOU"
    # }
    '{"ResponseBase64": "LS0tLS1CRUdJTiBQR1AgTUVTU0FHRS0tLS0tCgpoSXdETVl6a0NCNE44MmdCQS85TzBXbWQwS25ZNzVhZWJBZUFrclNIcUc2TDJBWXpmMWRSNWdEOUtuSHIzUFZCCnVyZmZGZUdlcWZTdHIyUVk4aE5aMkFseGpBdE8zdUwwR3NodGExZnkxT3dmemd4d1cyQmtaRm9xSFVuSHlXOTIKYXNJNlFuVkUyRGZHWElrWmoxdWVXRUtlbitOam05STgyelJNYjU0dmpoNGF6MTdhZ3ZlZjdsVUtoS0VTUU5MQQo0Z0hGVFdvNGhob2k1czgwbm1kQWM3YmZaMmJKK1BtOWpjcVJLcEIzK2JaSmhjbzFxaU1uM0E2bmVqZndVd3FYCmJxOFZaUjMrQjB3T2FhY1FrUHdTREJEbkNxKzhvUjZ5Z1prUHpLYzN2TGQ4ZGtScTZKYUREMzl2Qlp6amdnenQKZEpIenZsR1BoYjF1VVBhRHl1MlhyVkZPalhENGV4bjJqSXR6ditqNmpSb0dnM3Z4YU96akVsdWpRMGMyQ3NjKwp3bStmbEFBSEd1bGlJbkxrWEQydUxLQkNxOFJ3ektjc1lLbmljOGluQXpiSlQzM3RyNVdTWmdGcWpPakxIaWtiCnZGeVpEQ1lsMzRzMDM4dGlqaDErVC95akJlaUpmZjB6MjFRS2NVbGZtdU9JcEs0OGJPSkE5bDlWcmhhaFVYYU4Kclprck9JRU1USk55SmsyRi82S2ZnL3lwbWN0VnM3ZzRCMVR6Q0VDZ0tHcWxPWlYrRWhTcndiSXpwSGlTaDk1dApReWxLdm4wK1RZWkVVQWdVc3hnU2RUTllEcVBoZGkzYSt6SVBSMVVIeHhBT0prK3hrSW56T0VvYVp2Qm53bzN6ClB1UDNUQnYranlPN2kwVWYxZ1FyNnM0bEFMQ29jWWdabnNqRDRIb0VrZVMvRTNTaThOa2F4NTkzaFBXQ09hQmIKTTJ0eEYrOTdKWHVxUzlXbmRyKzh2MGlycGVDWU5seTU4bUZjSTFMdmJVa3ZGNWs9Cj1NR2RxCi0tLS0tRU5EIFBHUCBNRVNTQUdFLS0tLS0K"}'
  end

  def failed_authorisation_response
    '{
      "Id": "a20a6d39-e143-43d5-ade0-ebf5f76dcb87",
      "Code": "RJCT",
      "Message": "Invalid Account Number provided",
      "Errors": [{
        "ErrorCode": "RJCT",
        "Message": "[Collections] [Direct Debit Authorisation API] [VALIDATE_CDP_SHEX_DATA] -Invalid Account Number provided - Account Number attributes missing - accountType:null,institution:null, customerId:null"
      }]
    }'
  end

  def successful_authorize_confirmation_response
    # Encrypted and base64 encoded payload of:
    #
    # {
    #   "ProcessResult": {
    #     "ResponseCode": "00",
    #     "RejectReasonList": null
    #   }
    # }
    '{"ResponseBase64": "LS0tLS1CRUdJTiBQR1AgTUVTU0FHRS0tLS0tCgpoSXdETVl6a0NCNE44MmdCQkFDbnk5NHZjWTkzWVhwcGF5QkQrZHFQVlVZejUvUE5SV3h0Q3RVM2hSRXUvdElyCnlLRTh2VjRsbWE3eWxIUkJkMWI5SGd6RUxGMk9PYlFOZ1VTYTVEK1Z0VndOZHBubmZZUVhjd21ONWNYa2ZFcDEKN3cxb1Yva0JUNUxwa0NMalhOR2xndGxDRjFJVlMwYXRmZ2QwcERGK3pzcmhrWk5sM0FjdVZBbllBK3ZwNDlMQQpnQUhpZmUvYU5Fa0txQTZIcHVibk9LSzVnR2tDd0oxTU9FWitCM2Fiby9SaVZuSmhVYkw2ZjdVc2k3MEdnbVYwCkhKV3ppYTBicUcyK0lqR0twc2N2aHphUGNtRVpLeUxlS3RNK0kxMllRMHVnRzRqaGxpcHF4THRsL3JJUVZPd3QKai9uWHRYY1MyK0tudUs1d29wOEQvWk1XNGtWYVNQSExFZi8zbTBlVndBVjNOV21rTFl4TTRISEUxallONXIwNApIam0xbkU3UVhTd3N3Ukt0S04wZ1FZa1ZCUWhYWVZ4UC9UMEd2ZkpIajNSWVVLNStNU09ISE1RNmk2TVpjN2VJCjE2cFU1bDJaaGtSbU4zVDIzR09QQkRXVGdDZWhOcDY5YXoxNHljaS8rWEZmVW4zYklNWFlHRCs2UkRxWkJYVGcKaEd2U3JqL0NrSWlSMmxiMFo1dmlIWHdoVTRzN0JtaFlKOHJXckZHOVVic1pkNGFJTy92ZEdQKzVjRTV0ajYwRwpYZFRsL3V2Q1dpb0JvWXRJWWFQTmNBYjZiNWV5OFhZQnMwVHVvNk9DNXVXWgo9NWpqZwotLS0tLUVORCBQR1AgTUVTU0FHRS0tLS0tCg=="}'
  end

  def failed_authorize_confirmation_response
      '{
        "Id": "13df1c08-df15-40f7-935d-fc2d9aa3c41b",
        "Code": "RJCT",
        "Message": "Validation failed on MPP service.",
        "Errors": [{
          "ErrorCode": "MPP04003",
          "Message": "[Collections] [Direct Debit Authorisation Confirmation API] [VALIDATE_MPP_RESPONSE] - Validation failed on MPP service. - [MPP04003:OTP confirmation code is invalid]"
        }]
      }'
  end

  def successful_authorize_otp_regeneration
    # Encrypted and base64 encoded payload of:
    #
    # {
    #   "ProcessResult": {
    #     "ResponseCode": "00",
    #     "RejectReasonList": nil
    #   },
    #   "OtpIdentificationNumber": "123"
    # }
    '{"ResponseBase64": "LS0tLS1CRUdJTiBQR1AgTUVTU0FHRS0tLS0tCgpoSXdETVl6a0NCNE44MmdCQkFDR1lhY2hjUVVjTVVOdFpWcmQrQmxPU29WRFBER0ZGLzlKR3ZqeWYxMUgzMml1CjJXYk1ZQXMxUFo4dVBUd2w3ZTQ0Mmd5Ym5QTFZobldWajdCU1VMMUo2THRBdHlxa3ZHNklxR0dUdFBXNE9Sek8KTHVpTUJycEJZUm41N3VqZmY1bFdJUm4xcE9YMnM2SXRPdFBHWUZhaWs1d1BXbG5ZUkg2RW0xcXloL01TWnRMQQpvUUZyd1Z1SEVKbjNDVW84TDd0OXdlbXJOakI2NVVyMlUvdXZjdjRLcUhOeTFCMTJhRmJMN0NTamRUUVBZb09YCnRqZFRMYzRSV1R3QlJsbTc1K0VjNGxFSGxqemk3K2psK3QyKzRKU2VNYnk1N2J4akptMTh1WkVXVm1sOTEzYTEKakVDUnkzbis4TFNEdjdUdWJQU2F0alhZZnhacEU3ak5wbFZaNXZHZXA4dUptU2FMcmZwTnpCTFRnMHhoRUpjWQpFSlJCemI3bHdRN2JZaTNvdXRTSGgxYW5jTTVEeldFR3Y4dDBIS3pubG1iaUllaE5HZFc2SWNNSGthLzVtQlZGCnFnbUpPRGlwMmhTaGhQelZYOWZRZDR0NGg5aG5WQlRPeVAxTnNlS0NjOVVLbXZjZ01GRFdBSjVnNGl6S1JmQ0wKSzUyc3lLOEFFOFNKQlQ1R2wyb3QyeHlVYWM0NnV0eUdJYVpWZWFTdm9HczRTUWl2MlNQRHcrVERsWU9TaVBDbgp0b2hGTjQ5ZGl2T2ZPK1IvZkRYRm1XVnZMQWQ1L0Y0KzBOUW82UUYwWHhIbjlvbzJQcEY1V3JjZ3NaOHFUNGVYCi96TXp4dGsvRU9Wa01GUEFzMEFnU1FTRAo9SGo3TgotLS0tLUVORCBQR1AgTUVTU0FHRS0tLS0tCg=="}'
  end

  def pre_scrubbed
    <<-TRANSCRIPT
      opening connection to devcluster.api.p2g.netd2.hsbc.com.hk:443...
      opened
      starting SSL for devcluster.api.p2g.netd2.hsbc.com.hk:443...
      SSL established, protocol: TLSv1.2, cipher: ECDHE-RSA-AES128-GCM-SHA256
      <- "POST /cmb-connect-payments-pa-collection-cert-proxy/v1/direct-debits/authorisations HTTP/1.1\r\nContent-Type: application/json\r\nX-Hsbc-Country-Code: HK\r\nX-Hsbc-Client-Id: abc123def456ghi789jkl012mno345pq\r\nX-Hsbc-Client-Secret: qp543onm210lkj987ihg654fed321cba\r\nX-Hsbc-Profile-Id: PC1234567\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: devcluster.api.p2g.netd2.hsbc.com.hk\r\nContent-Length: 3028\r\n\r\n"
      <- "{\"RequestBase64\":\"LS0tLS1CRUdJTiBQR1AgTUVTU0FHRS0tLS0tCgpoSXdETVl6a0NCNE44MmdCQS8wZEVTckVETWtjM0lLWVFDVU5VdGVDMEdQNi95OFhZN04vQlN1ckh3TGUveFpjCmgvWk5JTCtRNlRsaG5udUtKeUJTMUhxZnAxVDR6bHloTWx2Mk9ZK0tySzd6YjR6ZG5nTDZyMzdoRTlVd1MvbE0KT1V3MmRmaVRRdnlhcytoVnFWUjAydjBQTnd5K0M2amwxdS9PZlExRW93SG1HUyt4UE80Qmc0eVlFa21vMU5McApBVlVKbWFoWTNtK3dMbjZzc0t3Y0RMV2hwTmJqWlM2MzZVU2J2a3hJK1lkV1F2QWl4SzROL1V4UXN5RUZRZGlPCnNPZTErNjFqSGpxT3pqQk9hVHlVTlJkcFJvZ25aVjAyRGZNdnB2NU1va21URkVJanVoeWdwYUpHeGhMMXRnL3MKaTdnYjk4TEpKaGdIMFVjb1M4SU1JZGpWSzBKcEpXY2VOWEZEZWR4NVNndVhTNUZOb2xaTFh2SWhiZEhvWmtKMgpnZE1Fd21JaktZbm9ydUlrRXNtRmZFdlAwRHNLSjJGQU1WL1VveGwwZ1RhbHJHcVZtQW9SSmVUZmdCZ0pUVXU5Cm1NeEtiSHRpenQzb2F0bUN1QVFqeU5nMWhRTC81M1VRQm1YWFcxcFdlQ09wRDVpZ2dPckFQdm0xZG9LQlJBd04Keno0dUltelN3aU1wUGlQUExxZmlhOFNUUkR1ZHVYbzZXVzJmSVhKNCtoNlJqdExsdm5UZHl2Q3AvQmdlSnAxWApMWm5ZTXBVLzM2NXJ5T29OMnJjckhXdTVibjF6c29yWDBtTnQxdHI0R1B6eXJNN3A5KzJaZWRtZ24reVRPdFBhCkdIQ09RdFYwMDd4NmxKVzAraXVRNCtCMXNnakowZjZRYVRPaE5kMStDcHhDZ2xSYXVlMUF1UGdjSHRsRzVoWG0KZUJDbC8wQ08rczJkekphY0JZc3JreWdSN1JlK1REek9EYUZRc2dOTlZSVDdUYWhNWFJUN2l3NENjalA0d2k4Mwp0ZSswdUpUYTJZVGswczNnRnE5aUZHNnpna2luL2hpYnIzMWJrS01PMG1EdEFUSmhWK2xtSG0ySTRNa1FNWUcxClYyd3ROL0kyNTM1bVU0UjNBcHJ4NWhpRDdtb2h4dGovNHRHN0xOdUsxNVVBCj1tV2dUCi0tLS0tRU5EIFBHUCBNRVNTQUdFLS0tLS0\"}"
      -> "HTTP/1.1 201 Created\r\n"
      -> "Date: Wed, 05 May 2021 00:22:20 GMT\r\n"
      -> "Server: rproxy\r\n"
      -> "X-Frame-Options: SAMEORIGIN\r\n"
      -> "expires: 0\r\n"
      -> "x-frame-options: DENY\r\n"
      -> "x-vcap-request-id: 7c3e1ecc-799e-4ed0-7bec-f72341668120\r\n"
      -> "x-hsbc-country-code: HK\r\n"
      -> "pragma: no-cache\r\n"
      -> "strict-transport-security: max-age=16070400; includeSubDomains\r\n"
      -> "access-control-expose-headers: x-hsbc-client-id,x-hsbc-profile-id,x-hsbc-country-code,x-hsbc-api-version,x-hsbc-api-build-version\r\n"
      -> "access-control-allow-origin: *\r\n"
      -> "x-hsbc-api-build-version: 1.4.1-20210503085316\r\n"
      -> "x-hsbc-client-id: abc123def456ghi789jkl012mno345pq\r\n"
      -> "x-content-type-options: nosniff\r\n"
      -> "x-xss-protection: 1; mode=block\r\n"
      -> "x-hsbc-profile-id: PC1234567\r\n"
      -> "content-type: application/json;charset=UTF-8\r\n"
      -> "x-hsbc-api-version: V1\r\n"
      -> "cache-control: max-age=0, no-store\r\n"
      -> "S: rproxy_dev_0230\r\n"
      -> "Transfer-Encoding: chunked\r\n"
      -> "Connection: close\r\n"
      -> "Set-Cookie: LB_COOKIE_1=2577846794.6265.0000; path=/; Httponly; Secure\r\n"
      -> "Public-Key-Pins: pin-sha256=\"86MuFNF1znOXnEbmS8PKZuYh+/3mzEh7c7dLzBuDeMM=\"; pin-sha256=\"l6Q+yQUkUtDXOiKXhjscuMB2J/5PMdXhMO/zt0QCdac=\"; pin-sha256=\"frdkSlW7rXJu9AhR8Ug/U4hnVkvj0InjKIYrzABTo1A=\"; max-age=1200;\r\n"
      -> "\r\n"
      -> "a19\r\n"
      reading 2585 bytes...
      -> ""
      -> "{\"ResponseBase64\":\"LS0tLS1CRUdJTiBQR1AgTUVTU0FHRS0tLS0tCgpoSXdETVl6a0NCNE44MmdCQS8wZEVTckVETWtjM0lLWVFDVU5VdGVDMEdQNi95OFhZN04vQlN1ckh3TGUveFpjCmgvWk5JTCtRNlRsaG5udUtKeUJTMUhxZnAxVDR6bHloTWx2Mk9ZK0tySzd6YjR6ZG5nTDZyMzdoRTlVd1MvbE0KT1V3MmRmaVRRdnlhcytoVnFWUjAydjBQTnd5K0M2amwxdS9PZlExRW93SG1HUyt4UE80Qmc0eVlFa21vMU5McApBVlVKbWFoWTNtK3dMbjZzc0t3Y0RMV2hwTmJqWlM2MzZVU2J2a3hJK1lkV1F2QWl4SzROL1V4UXN5RUZRZGlPCnNPZTErNjFqSGpxT3pqQk9hVHlVTlJkcFJvZ25aVjAyRGZNdnB2NU1va21URkVJanVoeWdwYUpHeGhMMXRnL3MKaTdnYjk4TEpKaGdIMFVjb1M4SU1JZGpWSzBKcEpXY2VOWEZEZWR4NVNndVhTNUZOb2xaTFh2SWhiZEhvWmtKMgpnZE1Fd21JaktZbm9ydUlrRXNtRmZFdlAwRHNLSjJGQU1WL1VveGwwZ1RhbHJHcVZtQW9SSmVUZmdCZ0pUVXU5Cm1NeEtiSHRpenQzb2F0bUN1QVFqeU5nMWhRTC81M1VRQm1YWFcxcFdlQ09wRDVpZ2dPckFQdm0xZG9LQlJBd04Keno0dUltelN3aU1wUGlQUExxZmlhOFNUUkR1ZHVYbzZXVzJmSVhKNCtoNlJqdExsdm5UZHl2Q3AvQmdlSnAxWApMWm5ZTXBVLzM2NXJ5T29OMnJjckhXdTVibjF6c29yWDBtTnQxdHI0R1B6eXJNN3A5KzJaZWRtZ24reVRPdFBhCkdIQ09RdFYwMDd4NmxKVzAraXVRNCtCMXNnakowZjZRYVRPaE5kMStDcHhDZ2xSYXVlMUF1UGdjSHRsRzVoWG0KZUJDbC8wQ08rczJkekphY0JZc3JreWdSN1JlK1REek9EYUZRc2dOTlZSVDdUYWhNWFJUN2l3NENjalA0d2k4Mwp0ZSswdUpUYTJZVGswczNnRnE5aUZHNnpna2luL2hpYnIzMWJrS01PMG1EdEFUSmhWK2xtSG0ySTRNa1FNWUcxClYyd3ROL0kyNTM1bVU0UjNBcHJ4NWhpRDdtb2h4dGovNHRHN0xOdUsxNVVBCj1tV2dUCi0tLS0tRU5EIFBHUCBNRVNTQUdFLS0tLS0\"}"
      read 2585 bytes
      reading 2 bytes...
      -> ""
      -> "\r\n"
      read 2 bytes
      -> "0\r\n"
      -> "\r\n"
      Conn close
    TRANSCRIPT
  end

  def post_scrubbed
    <<-TRANSCRIPT
      opening connection to devcluster.api.p2g.netd2.hsbc.com.hk:443...
      opened
      starting SSL for devcluster.api.p2g.netd2.hsbc.com.hk:443...
      SSL established, protocol: TLSv1.2, cipher: ECDHE-RSA-AES128-GCM-SHA256
      <- "POST /cmb-connect-payments-pa-collection-cert-proxy/v1/direct-debits/authorisations HTTP/1.1\r\nContent-Type: application/json\r\nX-Hsbc-Country-Code: HK\r\nX-Hsbc-Client-Id: [FILTERED]\r\nX-Hsbc-Client-Secret: [FILTERED]\r\nX-Hsbc-Profile-Id: PC1234567\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: devcluster.api.p2g.netd2.hsbc.com.hk\r\nContent-Length: 3028\r\n\r\n"
      <- "{\"RequestBase64\":\"LS0tLS1CRUdJTiBQR1AgTUVTU0FHRS0tLS0tCgpoSXdETVl6a0NCNE44MmdCQS8wZEVTckVETWtjM0lLWVFDVU5VdGVDMEdQNi95OFhZN04vQlN1ckh3TGUveFpjCmgvWk5JTCtRNlRsaG5udUtKeUJTMUhxZnAxVDR6bHloTWx2Mk9ZK0tySzd6YjR6ZG5nTDZyMzdoRTlVd1MvbE0KT1V3MmRmaVRRdnlhcytoVnFWUjAydjBQTnd5K0M2amwxdS9PZlExRW93SG1HUyt4UE80Qmc0eVlFa21vMU5McApBVlVKbWFoWTNtK3dMbjZzc0t3Y0RMV2hwTmJqWlM2MzZVU2J2a3hJK1lkV1F2QWl4SzROL1V4UXN5RUZRZGlPCnNPZTErNjFqSGpxT3pqQk9hVHlVTlJkcFJvZ25aVjAyRGZNdnB2NU1va21URkVJanVoeWdwYUpHeGhMMXRnL3MKaTdnYjk4TEpKaGdIMFVjb1M4SU1JZGpWSzBKcEpXY2VOWEZEZWR4NVNndVhTNUZOb2xaTFh2SWhiZEhvWmtKMgpnZE1Fd21JaktZbm9ydUlrRXNtRmZFdlAwRHNLSjJGQU1WL1VveGwwZ1RhbHJHcVZtQW9SSmVUZmdCZ0pUVXU5Cm1NeEtiSHRpenQzb2F0bUN1QVFqeU5nMWhRTC81M1VRQm1YWFcxcFdlQ09wRDVpZ2dPckFQdm0xZG9LQlJBd04Keno0dUltelN3aU1wUGlQUExxZmlhOFNUUkR1ZHVYbzZXVzJmSVhKNCtoNlJqdExsdm5UZHl2Q3AvQmdlSnAxWApMWm5ZTXBVLzM2NXJ5T29OMnJjckhXdTVibjF6c29yWDBtTnQxdHI0R1B6eXJNN3A5KzJaZWRtZ24reVRPdFBhCkdIQ09RdFYwMDd4NmxKVzAraXVRNCtCMXNnakowZjZRYVRPaE5kMStDcHhDZ2xSYXVlMUF1UGdjSHRsRzVoWG0KZUJDbC8wQ08rczJkekphY0JZc3JreWdSN1JlK1REek9EYUZRc2dOTlZSVDdUYWhNWFJUN2l3NENjalA0d2k4Mwp0ZSswdUpUYTJZVGswczNnRnE5aUZHNnpna2luL2hpYnIzMWJrS01PMG1EdEFUSmhWK2xtSG0ySTRNa1FNWUcxClYyd3ROL0kyNTM1bVU0UjNBcHJ4NWhpRDdtb2h4dGovNHRHN0xOdUsxNVVBCj1tV2dUCi0tLS0tRU5EIFBHUCBNRVNTQUdFLS0tLS0\"}"
      -> "HTTP/1.1 201 Created\r\n"
      -> "Date: Wed, 05 May 2021 00:22:20 GMT\r\n"
      -> "Server: rproxy\r\n"
      -> "X-Frame-Options: SAMEORIGIN\r\n"
      -> "expires: 0\r\n"
      -> "x-frame-options: DENY\r\n"
      -> "x-vcap-request-id: 7c3e1ecc-799e-4ed0-7bec-f72341668120\r\n"
      -> "x-hsbc-country-code: HK\r\n"
      -> "pragma: no-cache\r\n"
      -> "strict-transport-security: max-age=16070400; includeSubDomains\r\n"
      -> "access-control-expose-headers: x-hsbc-client-id,x-hsbc-profile-id,x-hsbc-country-code,x-hsbc-api-version,x-hsbc-api-build-version\r\n"
      -> "access-control-allow-origin: *\r\n"
      -> "x-hsbc-api-build-version: 1.4.1-20210503085316\r\n"
      -> "x-hsbc-client-id: [FILTERED]\r\n"
      -> "x-content-type-options: nosniff\r\n"
      -> "x-xss-protection: 1; mode=block\r\n"
      -> "x-hsbc-profile-id: PC1234567\r\n"
      -> "content-type: application/json;charset=UTF-8\r\n"
      -> "x-hsbc-api-version: V1\r\n"
      -> "cache-control: max-age=0, no-store\r\n"
      -> "S: rproxy_dev_0230\r\n"
      -> "Transfer-Encoding: chunked\r\n"
      -> "Connection: close\r\n"
      -> "Set-Cookie: LB_COOKIE_1=2577846794.6265.0000; path=/; Httponly; Secure\r\n"
      -> "Public-Key-Pins: pin-sha256=\"86MuFNF1znOXnEbmS8PKZuYh+/3mzEh7c7dLzBuDeMM=\"; pin-sha256=\"l6Q+yQUkUtDXOiKXhjscuMB2J/5PMdXhMO/zt0QCdac=\"; pin-sha256=\"frdkSlW7rXJu9AhR8Ug/U4hnVkvj0InjKIYrzABTo1A=\"; max-age=1200;\r\n"
      -> "\r\n"
      -> "a19\r\n"
      reading 2585 bytes...
      -> ""
      -> "{\"ResponseBase64\":\"LS0tLS1CRUdJTiBQR1AgTUVTU0FHRS0tLS0tCgpoSXdETVl6a0NCNE44MmdCQS8wZEVTckVETWtjM0lLWVFDVU5VdGVDMEdQNi95OFhZN04vQlN1ckh3TGUveFpjCmgvWk5JTCtRNlRsaG5udUtKeUJTMUhxZnAxVDR6bHloTWx2Mk9ZK0tySzd6YjR6ZG5nTDZyMzdoRTlVd1MvbE0KT1V3MmRmaVRRdnlhcytoVnFWUjAydjBQTnd5K0M2amwxdS9PZlExRW93SG1HUyt4UE80Qmc0eVlFa21vMU5McApBVlVKbWFoWTNtK3dMbjZzc0t3Y0RMV2hwTmJqWlM2MzZVU2J2a3hJK1lkV1F2QWl4SzROL1V4UXN5RUZRZGlPCnNPZTErNjFqSGpxT3pqQk9hVHlVTlJkcFJvZ25aVjAyRGZNdnB2NU1va21URkVJanVoeWdwYUpHeGhMMXRnL3MKaTdnYjk4TEpKaGdIMFVjb1M4SU1JZGpWSzBKcEpXY2VOWEZEZWR4NVNndVhTNUZOb2xaTFh2SWhiZEhvWmtKMgpnZE1Fd21JaktZbm9ydUlrRXNtRmZFdlAwRHNLSjJGQU1WL1VveGwwZ1RhbHJHcVZtQW9SSmVUZmdCZ0pUVXU5Cm1NeEtiSHRpenQzb2F0bUN1QVFqeU5nMWhRTC81M1VRQm1YWFcxcFdlQ09wRDVpZ2dPckFQdm0xZG9LQlJBd04Keno0dUltelN3aU1wUGlQUExxZmlhOFNUUkR1ZHVYbzZXVzJmSVhKNCtoNlJqdExsdm5UZHl2Q3AvQmdlSnAxWApMWm5ZTXBVLzM2NXJ5T29OMnJjckhXdTVibjF6c29yWDBtTnQxdHI0R1B6eXJNN3A5KzJaZWRtZ24reVRPdFBhCkdIQ09RdFYwMDd4NmxKVzAraXVRNCtCMXNnakowZjZRYVRPaE5kMStDcHhDZ2xSYXVlMUF1UGdjSHRsRzVoWG0KZUJDbC8wQ08rczJkekphY0JZc3JreWdSN1JlK1REek9EYUZRc2dOTlZSVDdUYWhNWFJUN2l3NENjalA0d2k4Mwp0ZSswdUpUYTJZVGswczNnRnE5aUZHNnpna2luL2hpYnIzMWJrS01PMG1EdEFUSmhWK2xtSG0ySTRNa1FNWUcxClYyd3ROL0kyNTM1bVU0UjNBcHJ4NWhpRDdtb2h4dGovNHRHN0xOdUsxNVVBCj1tV2dUCi0tLS0tRU5EIFBHUCBNRVNTQUdFLS0tLS0\"}"
      read 2585 bytes
      reading 2 bytes...
      -> ""
      -> "\r\n"
      read 2 bytes
      -> "0\r\n"
      -> "\r\n"
      Conn close
    TRANSCRIPT
  end
end
