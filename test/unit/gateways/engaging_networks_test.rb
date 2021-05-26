require 'test_helper'

class EngagingNetworksTest < Test::Unit::TestCase
  include CommStub

  def setup
    @gateway = EngagingNetworksGateway.new(api_key: 'foo')
    @credit_card = credit_card
    @amount = 100

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
      txn7: '[EVG][123][d63bbc3ace2d9df93013027510e66e]'
    }
  end

  def test_successful_purchase
    response =
      stub_comms do
        @gateway.purchase(@amount, @credit_card, @options)
      end.respond_with(
        successful_authenticate_response,
        successful_donation_response
      )

    assert_success response

    assert_equal '84074488135026237__2951266454422224__619253793273803',
                 response.authorization
    assert response.test?
  end

  def test_failed_purchase
    response =
      stub_comms do
        @gateway.purchase(@amount, @credit_card, @options)
      end.respond_with(
        successful_authenticate_response,
        failed_donation_response
      )

    assert_failure response
    assert_equal 'First Name is required for the Vantiv Gateway but was not passed in.',
                 response.message
  end

  def test_failed_authentication
    response_401 =
      stub(code: '401', message: 'Unauthorized', body: failed_login_response)
    @gateway
      .expects(:ssl_post)
      .raises(ActiveMerchant::ResponseError.new(response_401))
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'Invalid credentials', response.message
  end

  def test_scrub_card
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed_card), post_scrubbed_card
  end

  def test_scrub_check
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed_check), post_scrubbed_check
  end

  private

  def successful_authenticate_response
    '{"ens-auth-token":"307bb09d-8d05-4d5c-95bd-cf592dc37cf2","expires":3600000}'
  end

  def successful_donation_response
    '{"amount":1.0,"paymentType":"TEST: VI","recurringPayment":false,"createdOn":1621994124999,"error":"","supporterId":216617813,"supporterEmailAddress":"1621994123@fakeemailevg.com","transactionId":"84074488135026237__2951266454422224__619253793273803","currency":"USD","status":"SUCCESS","id":24010094,"type":"CREDIT_SINGLE"}'
  end

  def failed_donation_response
    '{"error":"First Name is required for the Vantiv Gateway but was not passed in.","supporterId":216617991,"supporterEmailAddress":"1621994677@fakeemailevg.com","status":"ERROR","id":1272014647}'
  end

  def pre_scrubbed_card
    %q(
      opening connection to e-activist.com:443...
      opened
      starting SSL for e-activist.com:443...
      SSL established, protocol: TLSv1.2, cipher: ECDHE-RSA-AES256-GCM-SHA384
      <- "POST /ens/service/authenticate HTTP/1.1\r\nContent-Type: application/json\r\nAccept-Encoding: identity\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: e-activist.com\r\nContent-Length: 36\r\n\r\n"
      <- "df33591e-5900-4804-a304-3a3c97553ff7"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Content-Encoding: identity\r\n"
      -> "Connection: close\r\n"
      -> "X-Powered-By: Undertow/1\r\n"
      -> "Server: WildFly/10\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Date: Mon, 24 May 2021 06:21:47 GMT\r\n"
      -> "\r\n"
      reading all...
      -> "{\"expires\":3600000,\"ens-auth-token\":\"56b0b4a9-851e-4857-b50b-d4386ee80075\"}"
      read 75 bytes
      Conn close
      opening connection to e-activist.com:443...
      opened
      starting SSL for e-activist.com:443...
      SSL established, protocol: TLSv1.2, cipher: ECDHE-RSA-AES256-GCM-SHA384
      <- "POST /ens/service/page/12345/process HTTP/1.1\r\nContent-Type: application/json\r\nEns-Auth-Token: 56b0b4a9-851e-4857-b50b-d4386ee80075\r\nAccept-Encoding: identity\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: e-activist.com\r\nContent-Length: 558\r\n\r\n"
      <- "{\"supporter\":{\"Email Address\":\"test@example.com\",\"First Name\":\"Longbob\",\"Last Name\":\"Longsen\",\"Birthday yyyy mm dd\":\"1981-01-01\",\"Mobile Phone\":\"(555)555-5555\",\"Home Phone\":null,\"questions\":{},\"Address 1\":\"456 My Street\",\"Address 2\":\"Apt 1\",\"City\":\"Hollywood\",\"State or Province\":\"CA\",\"ZIP or Postal Code\":\"90210\",\"Country\":\"US\"},\"transaction\":{\"paymenttype\":\"VI\",\"donationAmt\":\"1.00\",\"ccnumber\":\"4000100011112224\",\"ccvv\":\"123\",\"ccexpire\":\"0922\",\"recurrpay\":\"N\"},\"appealCode\":\"BBCRMSOURCECODE\",\"txn7\":\"[EVG][123][8133299d68a8de5ea3125ab10e820b]\",\"demo\":true}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Content-Encoding: identity\r\n"
      -> "X-Powered-By: Undertow/1\r\n"
      -> "Access-Control-Allow-Headers: Origin, Content-Type, Accept, Authorization, X-Requested-With, ens-auth-token, ens-client-id\r\n"
      -> "Server: WildFly/10\r\n"
      -> "Date: Mon, 24 May 2021 06:21:50 GMT\r\n"
      -> "Connection: close\r\n"
      -> "Access-Control-Allow-Origin: *\r\n"
      -> "Access-Control-Allow-Credentials: true\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS, HEAD\r\n"
      -> "\r\n"
      reading all...
      -> "{\"createdOn\":1621837310112,\"amount\":1.0,\"paymentType\":\"TEST: VI\",\"recurringPayment\":false,\"error\":\"\",\"transactionId\":\"84074475292837191__2951266454422224__362090122111489\",\"supporterEmailAddress\":\"test@example.com\",\"supporterId\":216282715,\"id\":23995860,\"type\":\"CREDIT_SINGLE\",\"currency\":\"USD\",\"status\":\"SUCCESS\"}"
      read 312 bytes
      Conn close
    )
  end

  def post_scrubbed_card
    %q(
      opening connection to e-activist.com:443...
      opened
      starting SSL for e-activist.com:443...
      SSL established, protocol: TLSv1.2, cipher: ECDHE-RSA-AES256-GCM-SHA384
      <- "POST /ens/service/authenticate HTTP/1.1\r\nContent-Type: application/json\r\nAccept-Encoding: identity\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: e-activist.com\r\nContent-Length: 36\r\n\r\n"
      <- "[FILTERED]"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Content-Encoding: identity\r\n"
      -> "Connection: close\r\n"
      -> "X-Powered-By: Undertow/1\r\n"
      -> "Server: WildFly/10\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Date: Mon, 24 May 2021 06:21:47 GMT\r\n"
      -> "\r\n"
      reading all...
      -> "{\"expires\":3600000,\"ens-auth-token\":\"[FILTERED]\"}"
      read 75 bytes
      Conn close
      opening connection to e-activist.com:443...
      opened
      starting SSL for e-activist.com:443...
      SSL established, protocol: TLSv1.2, cipher: ECDHE-RSA-AES256-GCM-SHA384
      <- "POST /ens/service/page/12345/process HTTP/1.1\r\nContent-Type: application/json\r\nEns-Auth-Token: [FILTERED]\r\nAccept-Encoding: identity\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: e-activist.com\r\nContent-Length: 558\r\n\r\n"
      <- "{\"supporter\":{\"Email Address\":\"test@example.com\",\"First Name\":\"Longbob\",\"Last Name\":\"Longsen\",\"Birthday yyyy mm dd\":\"1981-01-01\",\"Mobile Phone\":\"(555)555-5555\",\"Home Phone\":null,\"questions\":{},\"Address 1\":\"456 My Street\",\"Address 2\":\"Apt 1\",\"City\":\"Hollywood\",\"State or Province\":\"CA\",\"ZIP or Postal Code\":\"90210\",\"Country\":\"US\"},\"transaction\":{\"paymenttype\":\"VI\",\"donationAmt\":\"1.00\",\"ccnumber\":\"[FILTERED]\",\"ccvv\":\"[FILTERED]\",\"ccexpire\":\"0922\",\"recurrpay\":\"N\"},\"appealCode\":\"BBCRMSOURCECODE\",\"txn7\":\"[EVG][123][8133299d68a8de5ea3125ab10e820b]\",\"demo\":true}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Content-Encoding: identity\r\n"
      -> "X-Powered-By: Undertow/1\r\n"
      -> "Access-Control-Allow-Headers: Origin, Content-Type, Accept, Authorization, X-Requested-With, ens-auth-token, ens-client-id\r\n"
      -> "Server: WildFly/10\r\n"
      -> "Date: Mon, 24 May 2021 06:21:50 GMT\r\n"
      -> "Connection: close\r\n"
      -> "Access-Control-Allow-Origin: *\r\n"
      -> "Access-Control-Allow-Credentials: true\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS, HEAD\r\n"
      -> "\r\n"
      reading all...
      -> "{\"createdOn\":1621837310112,\"amount\":1.0,\"paymentType\":\"TEST: VI\",\"recurringPayment\":false,\"error\":\"\",\"transactionId\":\"84074475292837191__2951266454422224__362090122111489\",\"supporterEmailAddress\":\"test@example.com\",\"supporterId\":216282715,\"id\":23995860,\"type\":\"CREDIT_SINGLE\",\"currency\":\"USD\",\"status\":\"SUCCESS\"}"
      read 312 bytes
      Conn close
    )
  end

  def pre_scrubbed_check
    %q(
      opening connection to e-activist.com:443...
      opened
      starting SSL for e-activist.com:443...
      SSL established, protocol: TLSv1.2, cipher: ECDHE-RSA-AES256-GCM-SHA384
      <- "POST /ens/service/authenticate HTTP/1.1\r\nContent-Type: application/json\r\nAccept-Encoding: identity\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: e-activist.com\r\nContent-Length: 36\r\n\r\n"
      <- "df33591e-5900-4804-a304-3a3c97553ff7"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Content-Encoding: identity\r\n"
      -> "Connection: close\r\n"
      -> "X-Powered-By: Undertow/1\r\n"
      -> "Server: WildFly/10\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Date: Wed, 26 May 2021 01:46:09 GMT\r\n"
      -> "\r\n"
      reading all...
      -> "{\"expires\":3600000,\"ens-auth-token\":\"56b0b4a9-851e-4857-b50b-d4386ee80075\"}"
      read 75 bytes
      Conn close
      opening connection to e-activist.com:443...
      opened
      starting SSL for e-activist.com:443...
      SSL established, protocol: TLSv1.2, cipher: ECDHE-RSA-AES256-GCM-SHA384
      <- "POST /ens/service/page/12345/process HTTP/1.1\r\nContent-Type: application/json\r\nEns-Auth-Token: 56b0b4a9-851e-4857-b50b-d4386ee80075\r\nAccept-Encoding: identity\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: e-activist.com\r\nContent-Length: 558\r\n\r\n"
      <- "{\"supporter\":{\"Email Address\":\"test@example.com\",\"First Name\":\"Longbob\",\"Last Name\":\"Longsen\",\"Birthday yyyy mm dd\":\"1981-01-01\",\"Mobile Phone\":\"(555)555-5555\",\"Home Phone\":null,\"questions\":{},\"Address 1\":\"456 My Street\",\"Address 2\":\"Apt 1\",\"City\":\"Hollywood\",\"State or Province\":\"CA\",\"ZIP or Postal Code\":\"90210\",\"Country\":\"US\"},\"transaction\":{\"donationAmt\":\"1.00\",\"recurrpay\":\"N\",\"paymenttype\":\"Check\",\"bankaccnum\":\"15378535\",\"bankrtenum\":\"244183602\",\"bankacctype\":\"checking\"},\"appealCode\":\"BBCRMSOURCECODE\",\"txn7\":\"[EVG][123][82dbf5a28dac4fac1e29b535456010]\",\"demo\":true}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Content-Encoding: identity\r\n"
      -> "X-Powered-By: Undertow/1\r\n"
      -> "Access-Control-Allow-Headers: Origin, Content-Type, Accept, Authorization, X-Requested-With, ens-auth-token, ens-client-id\r\n"
      -> "Server: WildFly/10\r\n"
      -> "Date: Wed, 26 May 2021 01:46:09 GMT\r\n"
      -> "Connection: close\r\n"
      -> "Access-Control-Allow-Origin: *\r\n"
      -> "Access-Control-Allow-Credentials: true\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS, HEAD\r\n"
      -> "\r\n"
      reading all...
      -> "{\"amount\":1.0,\"paymentType\":\"TEST: Check\",\"recurringPayment\":false,\"createdOn\":1621993570723,\"error\":\"\",\"supporterId\":216617656,\"supporterEmailAddress\":\"1621993569@fakeemailevg.com\",\"transactionId\":\"ND216617656T8937111153482478592\",\"currency\":\"USD\",\"status\":\"SUCCESS\",\"id\":24010064,\"type\":\"CHECK\"}"
      read 312 bytes
      Conn close
    )
  end

  def post_scrubbed_check
    %q(
      opening connection to e-activist.com:443...
      opened
      starting SSL for e-activist.com:443...
      SSL established, protocol: TLSv1.2, cipher: ECDHE-RSA-AES256-GCM-SHA384
      <- "POST /ens/service/authenticate HTTP/1.1\r\nContent-Type: application/json\r\nAccept-Encoding: identity\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: e-activist.com\r\nContent-Length: 36\r\n\r\n"
      <- "[FILTERED]"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Content-Encoding: identity\r\n"
      -> "Connection: close\r\n"
      -> "X-Powered-By: Undertow/1\r\n"
      -> "Server: WildFly/10\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Date: Wed, 26 May 2021 01:46:09 GMT\r\n"
      -> "\r\n"
      reading all...
      -> "{\"expires\":3600000,\"ens-auth-token\":\"[FILTERED]\"}"
      read 75 bytes
      Conn close
      opening connection to e-activist.com:443...
      opened
      starting SSL for e-activist.com:443...
      SSL established, protocol: TLSv1.2, cipher: ECDHE-RSA-AES256-GCM-SHA384
      <- "POST /ens/service/page/12345/process HTTP/1.1\r\nContent-Type: application/json\r\nEns-Auth-Token: [FILTERED]\r\nAccept-Encoding: identity\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: e-activist.com\r\nContent-Length: 558\r\n\r\n"
      <- "{\"supporter\":{\"Email Address\":\"test@example.com\",\"First Name\":\"Longbob\",\"Last Name\":\"Longsen\",\"Birthday yyyy mm dd\":\"1981-01-01\",\"Mobile Phone\":\"(555)555-5555\",\"Home Phone\":null,\"questions\":{},\"Address 1\":\"456 My Street\",\"Address 2\":\"Apt 1\",\"City\":\"Hollywood\",\"State or Province\":\"CA\",\"ZIP or Postal Code\":\"90210\",\"Country\":\"US\"},\"transaction\":{\"donationAmt\":\"1.00\",\"recurrpay\":\"N\",\"paymenttype\":\"Check\",\"bankaccnum\":\"[FILTERED]\",\"bankrtenum\":\"[FILTERED]\",\"bankacctype\":\"checking\"},\"appealCode\":\"BBCRMSOURCECODE\",\"txn7\":\"[EVG][123][82dbf5a28dac4fac1e29b535456010]\",\"demo\":true}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Content-Encoding: identity\r\n"
      -> "X-Powered-By: Undertow/1\r\n"
      -> "Access-Control-Allow-Headers: Origin, Content-Type, Accept, Authorization, X-Requested-With, ens-auth-token, ens-client-id\r\n"
      -> "Server: WildFly/10\r\n"
      -> "Date: Wed, 26 May 2021 01:46:09 GMT\r\n"
      -> "Connection: close\r\n"
      -> "Access-Control-Allow-Origin: *\r\n"
      -> "Access-Control-Allow-Credentials: true\r\n"
      -> "Content-Type: application/json\r\n"
      -> "Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS, HEAD\r\n"
      -> "\r\n"
      reading all...
      -> "{\"amount\":1.0,\"paymentType\":\"TEST: Check\",\"recurringPayment\":false,\"createdOn\":1621993570723,\"error\":\"\",\"supporterId\":216617656,\"supporterEmailAddress\":\"1621993569@fakeemailevg.com\",\"transactionId\":\"ND216617656T8937111153482478592\",\"currency\":\"USD\",\"status\":\"SUCCESS\",\"id\":24010064,\"type\":\"CHECK\"}"
      read 312 bytes
      Conn close
    )
  end

  def failed_login_response
    '{"messageId":10000000,"message":"Invalid api key [foobar]"}'
  end
end
