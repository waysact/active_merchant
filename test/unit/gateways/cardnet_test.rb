require 'test_helper'

class CardnetTest < Test::Unit::TestCase
  def setup
    @gateway =
      CardnetGateway.new(
        merchant_id: 'login',
        terminal_id: 'password',
        currency: 124
      )
    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway
      .expects(:ssl_post)
      .twice
      .returns(successful_authorize_response, successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of MultiResponse, response
    assert_success response

    assert_equal '013140', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway
      .expects(:ssl_post)
      .twice
      .returns(successful_authorize_response, failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'amount: must be greater than 0', response.error_code
  end

  def test_successful_authorize; end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    %q(
      opening connection to lab.cardnet.com.do:443...
opened
starting SSL for lab.cardnet.com.do:443...
SSL established, protocol: TLSv1.2, cipher: ECDHE-RSA-AES128-GCM-SHA256
<- "POST /api/payment/idenpotency-keys HTTP/1.1\r\nContent-Type: application/json\r\nAccept: application/json\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: lab.cardnet.com.do\r\nContent-Length: 2\r\n\r\n"
<- "{}"
-> "HTTP/1.1 200 \r\n"
-> "Date: Tue, 22 Jun 2021 21:10:56 GMT\r\n"
-> "Server: Apache\r\n"
-> "X-Frame-Options: SAMEORIGIN\r\n"
-> "X-XSS-Protection: 1; mode=block\r\n"
-> "X-Content-Type-Options: nosniff\r\n"
-> "Content-Type: application/json\r\n"
-> "Content-Length: 37\r\n"
-> "Connection: close\r\n"
-> "\r\n"
reading 37 bytes...
-> ""
-> "ikey:f73898e8a77f479bb08d124d629b1be0"
read 37 bytes
Conn close
opening connection to lab.cardnet.com.do:443...
opened
starting SSL for lab.cardnet.com.do:443...
SSL established, protocol: TLSv1.2, cipher: ECDHE-RSA-AES128-GCM-SHA256
<- "POST /api/payment/transactions/sales HTTP/1.1\r\nContent-Type: application/json\r\nAccept: application/json\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: lab.cardnet.com.do\r\nContent-Length: 379\r\n\r\n"
<- "{\"tax\":0,\"tip\":0,\"amount\":100,\"currency\":\"214\",\"invoice-number\":\"BhLRJ7alVT\",\"card-number\":\"4000100011112224\",\"cvv\":\"123\",\"expiration-date\":\"09/22\",\"client-ip\":\"1.1.1.1\",\"environment\":\"ECommerce\",\"merchant-id\":\"349000000\",\"terminal-id\":\"58585858\",\"idempotency-key\":\"f73898e8a77f479bb08d124d629b1be0\",\"token\":\"TpCIj5Rqp3\",\"reference-number\":\"1e167001-c2b2-4eb1-b625-f38f7e912127\"}"
-> "HTTP/1.1 200 \r\n"
-> "Date: Tue, 22 Jun 2021 21:10:57 GMT\r\n"
-> "Server: Apache\r\n"
-> "X-Frame-Options: SAMEORIGIN\r\n"
-> "X-XSS-Protection: 1; mode=block\r\n"
-> "X-Content-Type-Options: nosniff\r\n"
-> "Content-Type: application/json\r\n"
-> "Connection: close\r\n"
-> "Transfer-Encoding: chunked\r\n"
-> "\r\n"
-> "11f\r\n"
reading 287 bytes...
-> "{\n  \"idempotency-key\" : \"f73898e8a77f479bb08d124d629b1be0\",\n  \"response-code\" : \"00\",\n  \"internal-response-code\" : \"0000\",\n  \"response-code-desc\" : \"Transaction Approved\",\n  \"response-code-source\" : \"gw\",\n  \"approval-code\" : \"012559\",\n  \"pnRef\" : \"txn-8567dd3d44ae496d8c4043b502f3d598\"\n}"
read 287 bytes
reading 2 bytes...
-> ""
-> "\r\n"
read 2 bytes
-> "0\r\n"
-> "\r\n"
Conn close
    )
  end

  def post_scrubbed
    "\n" + "      opening connection to lab.cardnet.com.do:443...\n" +
      "opened\n" + "starting SSL for lab.cardnet.com.do:443...\n" +
      "SSL established, protocol: TLSv1.2, cipher: ECDHE-RSA-AES128-GCM-SHA256\n" +
      "<- \"POST /api/payment/idenpotency-keys HTTP/1.1\\r\\nContent-Type: application/json\\r\\nAccept: application/json\\r\\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\\r\\nUser-Agent: Ruby\\r\\nConnection: close\\r\\nHost: lab.cardnet.com.do\\r\\nContent-Length: 2\\r\\n\\r\\n\"\n" +
      "<- \"{}\"\n" + "-> \"HTTP/1.1 200 \\r\\n\"\n" +
      "-> \"Date: Tue, 22 Jun 2021 21:10:56 GMT\\r\\n\"\n" +
      "-> \"Server: Apache\\r\\n\"\n" +
      "-> \"X-Frame-Options: SAMEORIGIN\\r\\n\"\n" +
      "-> \"X-XSS-Protection: 1; mode=block\\r\\n\"\n" +
      "-> \"X-Content-Type-Options: nosniff\\r\\n\"\n" +
      "-> \"Content-Type: application/json\\r\\n\"\n" +
      "-> \"Content-Length: 37\\r\\n\"\n" + "-> \"Connection: close\\r\\n\"\n" +
      "-> \"\\r\\n\"\n" + "reading 37 bytes...\n" + "-> \"\"\n" +
      "-> \"ikey:f73898e8a77f479bb08d124d629b1be0\"\n" + "read 37 bytes\n" +
      "Conn close\n" + "opening connection to lab.cardnet.com.do:443...\n" +
      "opened\n" + "starting SSL for lab.cardnet.com.do:443...\n" +
      "SSL established, protocol: TLSv1.2, cipher: ECDHE-RSA-AES128-GCM-SHA256\n" +
      "<- \"POST /api/payment/transactions/sales HTTP/1.1\\r\\nContent-Type: application/json\\r\\nAccept: application/json\\r\\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\\r\\nUser-Agent: Ruby\\r\\nConnection: close\\r\\nHost: lab.cardnet.com.do\\r\\nContent-Length: 379\\r\\n\\r\\n\"\n" +
      "<- \"{\\\"tax\\\":0,\\\"tip\\\":0,\\\"amount\\\":100,\\\"currency\\\":\\\"214\\\",\\\"invoice-number\\\":\\\"BhLRJ7alVT\\\",\\\"card-number\\\":\\\"[FILTERED]\\\",\\\"cvv\\\":\\\"[FILTERED]\\\",\\\"expiration-date\\\":\\\"09/22\\\",\\\"client-ip\\\":\\\"1.1.1.1\\\",\\\"environment\\\":\\\"ECommerce\\\",\\\"merchant-id\\\":\\\"[FILTERED]\\\",\\\"terminal-id\\\":\\\"[FILTERED]\\\",\\\"idempotency-key\\\":\\\"f73898e8a77f479bb08d124d629b1be0\\\",\\\"token\\\":\\\"TpCIj5Rqp3\\\",\\\"reference-number\\\":\\\"1e167001-c2b2-4eb1-b625-f38f7e912127\\\"}\"\n" +
      "-> \"HTTP/1.1 200 \\r\\n\"\n" +
      "-> \"Date: Tue, 22 Jun 2021 21:10:57 GMT\\r\\n\"\n" +
      "-> \"Server: Apache\\r\\n\"\n" +
      "-> \"X-Frame-Options: SAMEORIGIN\\r\\n\"\n" +
      "-> \"X-XSS-Protection: 1; mode=block\\r\\n\"\n" +
      "-> \"X-Content-Type-Options: nosniff\\r\\n\"\n" +
      "-> \"Content-Type: application/json\\r\\n\"\n" +
      "-> \"Connection: close\\r\\n\"\n" +
      "-> \"Transfer-Encoding: chunked\\r\\n\"\n" + "-> \"\\r\\n\"\n" +
      "-> \"11f\\r\\n\"\n" + "reading 287 bytes...\n" +
      "-> \"{\\n  \\\"idempotency-key\\\" : \\\"f73898e8a77f479bb08d124d629b1be0\\\",\\n  \\\"response-code\\\" : \\\"00\\\",\\n  \\\"internal-response-code\\\" : \\\"0000\\\",\\n  \\\"response-code-desc\\\" : \\\"Transaction Approved\\\",\\n  \\\"response-code-source\\\" : \\\"gw\\\",\\n  \\\"approval-code\\\" : \\\"012559\\\",\\n  \\\"pnRef\\\" : \\\"txn-8567dd3d44ae496d8c4043b502f3d598\\\"\\n}\"\n" +
      "read 287 bytes\n" + "reading 2 bytes...\n" + "-> \"\"\n" +
      "-> \"\\r\\n\"\n" + "read 2 bytes\n" + "-> \"0\\r\\n\"\n" +
      "-> \"\\r\\n\"\n" + "Conn close\n" + '    '
  end

  def successful_purchase_response
    '{
      "idempotency-key" : "6fc3f9bf974443f18e854ff50d31fe73",
      "response-code" : "00",
      "internal-response-code" : "0000",
      "response-code-desc" : "Transaction Approved",
      "response-code-source" : "gw",
      "approval-code" : "013140",
      "pnRef" : "txn-89b3c6abcbf044b0a7a3da998bb7a456"
    }'
  end

  def failed_purchase_response
    '{
      "path" : "/api/payment/transactions/sales",
      "error" : "Incoming data validation error",
      "message" : "Incoming data validation error",
      "errors" : [ {
        "field" : "amount",
        "message" : "must be greater than 0"
      } ],
      "status" : "400",
      "timestamp" : "1624401063753"
    }'
  end

  def successful_authorize_response
    'ikey:f73898e8a77f479bb08d124d629b1be0'
  end
end
