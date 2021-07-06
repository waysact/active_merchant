require 'test_helper'

class EpaycoTest < Test::Unit::TestCase
  def setup
    @gateway = EpaycoGateway.new(public_key: 'TEST', private_key: 'TEST')
    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase',
      client_id_type: 'CC',
      client_id_number: '312558586',
      first_name: 'Jon',
      last_name: 'Doe',
      email: 'jondoe@email.com',
      mobile_phone: '0000000000',
      phone: '0000000',
      ip: '127.0.0.1'
    }

    @bank_options =
      { url_response: 'www.prueba.com', person_type: 1 }.merge(@options)
  end

  def test_successful_purchase
    @gateway.expects(:ssl_request).returns(successful_purchase_response)
    @gateway.expects(:access_token).returns('TOOKEN')

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal '000000', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_request).returns(failed_purchase_response)
    @gateway.expects(:access_token).returns('TOOKEN')

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'E014: La transaccion no se puede iniciar, monto minimo no superado',
                 response.error_code
  end

  def test_successful_get_financial_institutions
    @gateway
      .expects(:ssl_request)
      .returns(successful_get_financial_institutions)
    @gateway.expects(:access_token).returns('TOOKEN')

    response = @gateway.get_financial_institutions

    banks_description = [
      { 'bankCode' => '0', 'bankName' => 'A continuación seleccione su banco' },
      { 'bankCode' => '1077', 'bankName' => 'BANKA' }
    ]

    assert_equal 'Bancos consultados exitosamente PseController',
                 response.message
    assert_equal banks_description, response.params['data']
    assert response.test?
  end

  def test_pending_pse
    @gateway.expects(:ssl_request).returns(successful_purchase_pse_response)
    @gateway.expects(:access_token).returns('TOOKEN')

    response = @gateway.purchase(@amount, check, @bank_options)
    assert_success response

    assert_equal '2212410', response.authorization
    assert response.test?
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    <<-'PRE_SCRUBBED'
    opening connection to apify.epayco.co:443...
opened
starting SSL for apify.epayco.co:443...
SSL established, protocol: TLSv1.2, cipher: ECDHE-RSA-AES128-GCM-SHA256
<- "POST /login HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: Basic NWE0MGYzMTk0ODgyODQ3NGM2N2Y0YjMyNDI5ZDIzNGM6ZjYwODliYjVkNWY3NmRiNjRhZTk3ZDg1MmU4YTVhMmM=\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: apify.epayco.co\r\nContent-Length: 1\r\n\r\n"
<- " "
-> "HTTP/1.1 200 OK\r\n"
-> "Date: Mon, 05 Jul 2021 15:00:01 GMT\r\n"
-> "Content-Type: application/json\r\n"
-> "Content-Length: 248\r\n"
-> "Connection: close\r\n"
-> "Server: Apache\r\n"
-> "Vary: Authorization\r\n"
-> "X-Powered-By: PHP/7.3.28\r\n"
-> "Cache-Control: no-cache, private\r\n"
-> "Access-Control-Allow-Origin: *\r\n"
-> "Access-Control-Allow-Methods: GET,POST,OPTIONS,DELETE,PUT\r\n"
-> "Access-Control-Allow-Credentials: true\r\n"
-> "Access-Control-Max-Age: 86400\r\n"
-> "Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With\r\n"
-> "\r\n"
reading 248 bytes...
-> "{\"token\":\"eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJhcGlmeWVQYXljb0pXVCIsInN1YiI6NTIzMDk0LCJpYXQiOjE2MjU0OTcyMDEsImV4cCI6MTYyNTUwMDgwMSwicmFuZCI6IjA3OWRmZmNhMmY3ZmM2MzA3NzNmYTFmY2ViNmExNTdhNjM5In0.mSQrcC7TfrNkUWozmoS37UDxulEKMZBwxypRmRNITFs\"}"
read 248 bytes
Conn close
opening connection to apify.epayco.co:443...
opened
starting SSL for apify.epayco.co:443...
SSL established, protocol: TLSv1.2, cipher: ECDHE-RSA-AES128-GCM-SHA256
<- "POST /payment/process HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJhcGlmeWVQYXljb0pXVCIsInN1YiI6NTIzMDk0LCJpYXQiOjE2MjU0OTcyMDEsImV4cCI6MTYyNTUwMDgwMSwicmFuZCI6IjA3OWRmZmNhMmY3ZmM2MzA3NzNmYTFmY2ViNmExNTdhNjM5In0.mSQrcC7TfrNkUWozmoS37UDxulEKMZBwxypRmRNITFs\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: apify.epayco.co\r\nContent-Length: 350\r\n\r\n"
<- "{\"value\":\"100000.00\",\"currency\":\"COP\",\"dues\":\"1\",\"cardNumber\":\"4575623182290326\",\"cardExpMonth\":\"09\",\"cardExpYear\":\"2022\",\"cardCvc\":\"123\",\"address\":null,\"docType\":\"CC\",\"docNumber\":\"312558586\",\"name\":\"Jon\",\"email\":\"jondoe@email.com\",\"cellPhone\":\"0000000000\",\"phone\":\"0000000\",\"ip\":\"127.0.0.1\",\"typePerson\":0,\"lastName\":\"Doe\",\"methodConfimation\":\"GET\"}"
-> "HTTP/1.1 200 OK\r\n"
-> "Date: Mon, 05 Jul 2021 15:00:08 GMT\r\n"
-> "Content-Type: application/json\r\n"
-> "Content-Length: 872\r\n"
-> "Connection: close\r\n"
-> "Server: Apache\r\n"
-> "Vary: Authorization\r\n"
-> "X-Powered-By: PHP/7.3.28\r\n"
-> "Cache-Control: no-cache, private\r\n"
-> "Access-Control-Allow-Origin: *\r\n"
-> "Access-Control-Allow-Methods: GET,POST,OPTIONS,DELETE,PUT\r\n"
-> "Access-Control-Allow-Credentials: true\r\n"
-> "Access-Control-Max-Age: 86400\r\n"
-> "Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With\r\n"
-> "\r\n"
reading 872 bytes...
-> "{\"success\":true,\"titleResponse\":\"Success transaction\",\"textResponse\":\"Success transaction\",\"lastAction\":\"transaction_split_payment_tc\",\"data\":{\"transaction\":{\"status\":true,\"success\":true,\"type\":\"Create payment\",\"data\":{\"ref_payco\":54542399,\"factura\":\"QR-APIFY1625497202\",\"descripcion\":\"Compra referencia QR-APIFY1625497202\",\"valor\":\"100000.00\",\"iva\":\"0\",\"baseiva\":0,\"moneda\":\"COP\",\"banco\":\"Banco de Pruebas\",\"estado\":\"Aceptada\",\"respuesta\":\"Aprobada\",\"autorizacion\":\"000000\",\"recibo\":\"54542399\",\"fecha\":\"2021-07-05 10:00:04\",\"franquicia\":\"VS\",\"cod_respuesta\":1,\"ip\":\"127.0.0.1\",\"enpruebas\":1,\"tipo_doc\":\"CC\",\"documento\":\"312558586\",\"nombres\":\"Jon\",\"apellidos\":\"Doe\",\"email\":\"jondoe@email.com\",\"ciudad\":\"NA\",\"direccion\":\"SIN DIRECCION\",\"ind_pais\":\"\"},\"object\":\"payment\"},\"tokenCard\":{\"email\":\"jondoe@email.com\",\"cardTokenId\":\"0e31e7339087e19833e9844\",\"customerId\":\"N\\/A\"}}}"
read 872 bytes
Conn close
    PRE_SCRUBBED
  end

  def post_scrubbed
    <<-'POST_SCRUBBED'
    opening connection to apify.epayco.co:443...
opened
starting SSL for apify.epayco.co:443...
SSL established, protocol: TLSv1.2, cipher: ECDHE-RSA-AES128-GCM-SHA256
<- "POST /login HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: Basic [FILTERED]=\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: apify.epayco.co\r\nContent-Length: 1\r\n\r\n"
<- " "
-> "HTTP/1.1 200 OK\r\n"
-> "Date: Mon, 05 Jul 2021 15:00:01 GMT\r\n"
-> "Content-Type: application/json\r\n"
-> "Content-Length: 248\r\n"
-> "Connection: close\r\n"
-> "Server: Apache\r\n"
-> "Vary: Authorization\r\n"
-> "X-Powered-By: PHP/7.3.28\r\n"
-> "Cache-Control: no-cache, private\r\n"
-> "Access-Control-Allow-Origin: *\r\n"
-> "Access-Control-Allow-Methods: GET,POST,OPTIONS,DELETE,PUT\r\n"
-> "Access-Control-Allow-Credentials: true\r\n"
-> "Access-Control-Max-Age: 86400\r\n"
-> "Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With\r\n"
-> "\r\n"
reading 248 bytes...
-> "{\"token\":[FILTERED]}"
read 248 bytes
Conn close
opening connection to apify.epayco.co:443...
opened
starting SSL for apify.epayco.co:443...
SSL established, protocol: TLSv1.2, cipher: ECDHE-RSA-AES128-GCM-SHA256
<- "POST /payment/process HTTP/1.1\r\nContent-Type: application/json\r\nAuthorization: Bearer [FILTERED]\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nConnection: close\r\nHost: apify.epayco.co\r\nContent-Length: 350\r\n\r\n"
<- "{\"value\":\"100000.00\",\"currency\":\"COP\",\"dues\":\"1\",\"cardNumber\":\"[FILTERED]\",\"cardExpMonth\":\"09\",\"cardExpYear\":\"2022\",\"cardCvc\":\"[FILTERED]\",\"address\":null,\"docType\":\"CC\",\"docNumber\":\"312558586\",\"name\":\"Jon\",\"email\":\"jondoe@email.com\",\"cellPhone\":\"0000000000\",\"phone\":\"0000000\",\"ip\":\"127.0.0.1\",\"typePerson\":0,\"lastName\":\"Doe\",\"methodConfimation\":\"GET\"}"
-> "HTTP/1.1 200 OK\r\n"
-> "Date: Mon, 05 Jul 2021 15:00:08 GMT\r\n"
-> "Content-Type: application/json\r\n"
-> "Content-Length: 872\r\n"
-> "Connection: close\r\n"
-> "Server: Apache\r\n"
-> "Vary: Authorization\r\n"
-> "X-Powered-By: PHP/7.3.28\r\n"
-> "Cache-Control: no-cache, private\r\n"
-> "Access-Control-Allow-Origin: *\r\n"
-> "Access-Control-Allow-Methods: GET,POST,OPTIONS,DELETE,PUT\r\n"
-> "Access-Control-Allow-Credentials: true\r\n"
-> "Access-Control-Max-Age: 86400\r\n"
-> "Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With\r\n"
-> "\r\n"
reading 872 bytes...
-> "{\"success\":true,\"titleResponse\":\"Success transaction\",\"textResponse\":\"Success transaction\",\"lastAction\":\"transaction_split_payment_tc\",\"data\":{\"transaction\":{\"status\":true,\"success\":true,\"type\":\"Create payment\",\"data\":{\"ref_payco\":54542399,\"factura\":\"QR-APIFY1625497202\",\"descripcion\":\"Compra referencia QR-APIFY1625497202\",\"valor\":\"100000.00\",\"iva\":\"0\",\"baseiva\":0,\"moneda\":\"COP\",\"banco\":\"Banco de Pruebas\",\"estado\":\"Aceptada\",\"respuesta\":\"Aprobada\",\"autorizacion\":\"000000\",\"recibo\":\"54542399\",\"fecha\":\"2021-07-05 10:00:04\",\"franquicia\":\"VS\",\"cod_respuesta\":1,\"ip\":\"127.0.0.1\",\"enpruebas\":1,\"tipo_doc\":\"CC\",\"documento\":\"312558586\",\"nombres\":\"Jon\",\"apellidos\":\"Doe\",\"email\":\"jondoe@email.com\",\"ciudad\":\"NA\",\"direccion\":\"SIN DIRECCION\",\"ind_pais\":\"\"},\"object\":\"payment\"},\"tokenCard\":{\"email\":\"jondoe@email.com\",\"cardTokenId\":\"0e31e7339087e19833e9844\",\"customerId\":\"N\\/A\"}}}"
read 872 bytes
Conn close
    POST_SCRUBBED
  end

  def successful_purchase_response
    '{
      "success":true,
      "titleResponse":"Success transaction",
      "textResponse":"Success transaction",
      "lastAction":"transaction_split_payment_tc",
      "data":{
        "transaction":{
          "status":true,
          "success":true,
          "type":"Create payment",
          "data":{
            "ref_payco":54424084,
            "factura":"QR-APIFY1625320736",
            "descripcion":"Compra referencia QR-APIFY1625320736",
            "valor":"100000.00",
            "iva":"0",
            "baseiva":0,
            "moneda":"COP",
            "banco":"Banco de Pruebas",
            "estado":"Aceptada",
            "respuesta":"Aprobada",
            "autorizacion":"000000",
            "recibo":"54424084",
            "fecha":"2021-07-03 08:58:58",
            "franquicia":"VS",
            "cod_respuesta":1,
            "ip":"127.0.0.1",
            "enpruebas":1,
            "tipo_doc":"CC",
            "documento":"312558586",
            "nombres":"Jon",
            "apellidos":"Doe",
            "email":"jondoe@email.com",
            "ciudad":"NA",
            "direccion":"SIN DIRECCION",
            "ind_pais":""
          },
          "object":"payment"
        },
        "tokenCard":{
          "email":"jondoe@email.com",
          "cardTokenId":"0e06d211fb3f95a75497cb3",
          "customerId":"N\/A"
        }
      }
    }'
  end

  def successful_purchase_pse_response
    '{
      "success":true,
      "titleResponse":"Success transaction pse",
      "textResponse":"Success transaction pse",
      "lastAction":"transaction_split_payment_pse",
      "data":{
        "ref_payco":54557547,
        "factura":"QR-APIFY-PSE12532d9115654b7b5d77750b77eadede14",
        "descripcion":"Pago Factura #QR-APIFY-PSE12532d9115654b7b5d77750b77eadede14",
        "valor":100000,
        "iva":0,
        "baseiva":0,
        "moneda":"COP",
        "estado":"Pendiente",
        "respuesta":"Redireccionando al banco",
        "autorizacion":"2212410",
        "recibo":"545575471625513173",
        "fecha":"2021-07-05 1426:13",
        "urlbanco":"https:\/\/registro.desarrollo.pse.com.co\/PSENF\/index.html?enc=A5NQdosf27JpGtPuwB%2bZOGUfZImw7aBMdxiG4fFXw9o%3d",
        "transactionID":"2212410",
        "ticketId":"545575471625513173"
      }
    }'
  end

  def failed_purchase_response
    '{
      "success":false,
      "titleResponse":"Error create transaction",
      "textResponse":"Error create transaction Cliente o token inexistente",
      "lastAction":"create_transaction",
      "data":{
        "error":{
          "status":"error",
          "description":"Verifica que los datos enviados seran existentes o correctos.",
          "errors":[{
            "codError":"E014",
            "errorMessage":"La transaccion no se puede iniciar, monto minimo no superado"
          }]
        },
        "tokenCard":{
          "email":"jondoe@email.com",
          "cardTokenId":"0e08a5e5eae041b7d0243c9",
          "customerId":"N\/A"
        }
      }
    }'
  end

  def successful_get_financial_institutions
    '{
      "success":true,
      "titleResponse":"Ok",
      "textResponse":"Bancos consultados exitosamente PseController",
      "lastAction":"Query Bancos",
      "data":[{
        "bankCode":"0",
        "bankName":"A continuación seleccione su banco"
      },{
        "bankCode":"1077",
        "bankName":"BANKA"
      }]
    }'
  end
end
