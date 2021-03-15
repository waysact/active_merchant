module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class SimplePayGateway < Gateway
      # self.test_url = 'https://sandbox.simplepay.hu/payment/v2'
      self.test_url = 'https://sandbox.simplepay.hu/payment'
      self.live_url = 'https://secure.simplepay.hu/payment/v2'

      self.supported_countries = ['US']
      self.default_currency = 'USD'

      #     Currencies:
      # Forint (HUF), Euro (EUR) or Dollar (USD)
      self.supported_cardtypes = %i[visa master american_express discover]

      self.homepage_url = 'https://simplepay.hu/'
      self.display_name = 'SimplePay'

      STANDARD_ERROR_CODE_MAPPING = {}

      def initialize(options = {})
        requires!(options, :secret_key, :merchant_id)
        super
      end

      def purchase(money, payment, options = {})
        post = {}
        add_invoice(post, options)
        add_payment(post, money, payment)
        # add_address(post, payment, options)
        # add_customer_data(post, options)

        post['salt'] = SecureRandom.uuid.gsub('-', '')
        post['orderRef'] = options[:reference]
        post['merchant'] = @options[:merchant_id]
        post['customerEmail'] = options[:email]
        post['language'] = options[:language] || 'HU'
        post['sdkVersion'] = options[:skd_version] || 'SimplePayV2.1_Payment_PHP_SDK_2.0.7_190701:dd236896400d7463677a82a47f53e36e'
        post['methods'] = [ 'CARD' ]
        post['timeout'] = Time.current.iso8601
        post['url'] = 'http://localhost:7000/simplepay'

        # commit('/start', post)
        commit('/v2/start', post)
      end

      def authorize(money, payment, options = {})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, payment, options)
        add_customer_data(post, options)

        commit('authonly', post)
      end

      def capture(money, authorization, options = {})
        commit('capture', post)
      end

      def refund(money, authorization, options = {})
        commit('refund', post)
      end

      def void(authorization, options = {})
        commit('void', post)
      end

      def verify(credit_card, options = {})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript
      end

      private

      def add_customer_data(post, options)
      end

      def add_address(post, creditcard, options)
      end

      def add_invoice(post, options)
        invoice = {}

        address = options[:address] || {}

        invoice['name'] = 'SimplePay V2 Tester'
        invoice['company'] = ''
        invoice['country'] = address[:country]
        invoice['state'] = address[:state]
        invoice['city'] = address[:city]
        invoice['zip'] = address[:postcode] || address[:zip]
        invoice['address'] = address[:address1]
        invoice['address2'] = address[:address2]
        invoice['phone'] = address[:phone]

        post['invoice'] = invoice
      end

      def add_payment(post, money, payment)
        post['total'] = amount(money)
        post['currency'] = (options[:currency] || currency(money))
      end

      def parse(body)
        {}
      end

      def headers(data)
        key = @options[:secret_key]
        digest_algorithm = OpenSSL::Digest.new('sha384')
        digest_signature = OpenSSL::HMAC.digest(digest_algorithm, key, data)
        encoded_signature = Base64.encode64(digest_signature).gsub(/\n/, '')

        # {
        #   'Signature' => encoded_signature,
        #   'Content-Type' => 'application/json'
        # }

        {
          'Signature' => 'rV2AffURYaUFMDhZgwN7fYZha0XGFCqsvBlRotCWg4MZ5e/EBZIVU3Vn8yypimPy',
          'Content-Type' => 'application/json;charset=utf-8'
        }
      end

      def commit(action, parameters)
        url = (test? ? test_url : live_url) + action
        # payload = post_data(action, parameters)
        payload = {
          "salt" => "126dac8a12693a6475c7c24143024ef8",
          "merchant" => "P120503",
          "orderRef" => "101010515680292482600",
          "currency" => "HUF",
          "customerEmail" => "sdk_test@otpmobil.com",
          "language" => "EN",
          "sdkVersion" => "SimplePay_PHP_SDK_2.1.0_200825:c8f0c15958c8bc6f37ade6563296dcbf",
          "methods" => ["CARD"],
          "total" => "25",
          "timeout" => "2019-09-11T19:14:08+00:00",
          'threeDSReqAuthMethod' => '02',
          "url" => "https:\/\/sdk.simplepay.hu\/back.php",
          "invoice" => {
            "name" => "SimplePay V2 Tester",
            "company" => "",
            "country" => "hu",
            "state" => "Budapest",
            "city" => "Budapest",
            "zip" => "1111",
            "address" => "Address 1",
            "address2" => "Address 2",
            "phone" => "06203164978"
          },
          "items" => [
            {
              "ref" => "Product ID 1",
              "title" => "Product name 1",
              "description" => "Product description 1",
              "amount" => "1",
              "price" => "10",
              "tax" => "0"
            }]
        }.to_s

        puts
        puts " # ========== commit ============== "
        puts " # url = #{url}"
        puts " # headers(payload) = #{headers(payload)}"
        puts " # payload = #{payload}"
        puts

        response = parse(ssl_post(url, payload, headers(payload)))

        puts
        puts " # response = #{response}"
        puts " # ===================== "
        puts


        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          avs_result: AVSResult.new(code: response['some_avs_response_key']),
          cvv_result: CVVResult.new(response['some_cvv_response_key']),
          test: test?,
          error_code: error_code_from(response),
        )
      end

      def success_from(response); end

      def message_from(response); end

      def authorization_from(response); end

      def post_data(action, parameters = {})
        parameters.to_s
      end

      def error_code_from(response)
        unless success_from(response)
          # TODO: lookup error code for this response
        end
      end
    end
  end
end
