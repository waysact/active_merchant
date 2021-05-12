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
    @gateway.expects(:ssl_post).returns(failed_authorisation_response)

    response = @gateway.authorize(@amount, @direct_debit, @options)
    assert_failure response
    assert_equal 'RJCT', response.error_code
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def successful_authorisation_response
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
