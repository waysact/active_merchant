module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class CardnetGateway < Gateway
      self.test_url = 'https://lab.cardnet.com.do/api/payment'
      self.live_url = 'https://ecommerce.cardnet.com.do/api/payment'

      self.supported_countries = ['DO']
      self.default_currency = 'DOP'
      self.supported_cardtypes = %i[visa master american_express discover]

      self.homepage_url = 'https://www.cardnet.com.do/'
      self.display_name = 'CardNet'

      self.money_format = :cents

      def initialize(options = {})
        requires!(options, :merchant_id, :terminal_id, :currency)
        super
      end

      def purchase(money, payment, options = {})
        MultiResponse.run do |r|
          r.process { authorize }
          r.process do
            capture(
              money,
              payment,
              options.merge(authorization: r.authorization)
            )
          end
        end
      end

      def authorize(options = {})
        post = {}

        commit('/idenpotency-keys', post)
      end

      def capture(money, payment, options = {})
        post = {}

        add_invoice(post, money, options)
        add_payment(post, payment)
        add_customer_data(post, options)
        add_references(post, options)

        commit('/transactions/sales', post)
      end

      def void(authorization, options = {})
        post = {}

        post['pnRef'] = authorization

        add_references(post, options)
        add_customer_data(post, options)
        add_invoice(post, options[:amount], options)

        commit('/transactions/voids', post)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript
          .gsub(/("card-number\\":\\")\d+/, '\1[FILTERED]')
          .gsub(/("terminal-id\\":\\")\d+/, '\1[FILTERED]')
          .gsub(/("merchant-id\\":\\")\d+/, '\1[FILTERED]')
          .gsub(/("cvv\\":\\")\d+/, '\1[FILTERED]')
      end

      private

      def headers
        { 'accept' => 'application/json', 'Content-Type' => 'application/json' }
      end

      def add_customer_data(post, options)
        post['client-ip'] = options[:ip]
        post['environment'] = options[:environment] || 'ECommerce'
      end

      def add_invoice(post, money, options)
        post['tax'] = options[:tax] || 0
        post['tip'] = options[:tip] || 0
        post['amount'] = amount(money).to_i
        post['currency'] = (@options[:currency] || currency(money)).to_s
        post['invoice-number'] = options[:invoice] if options[:invoice]
        post['pstr43'] = options[:pstr43] if options[:pstr43].present?
      end

      def add_payment(post, payment)
        post['card-number'] = payment.number
        post['cvv'] = payment.verification_value
        month = format(payment.month, :two_digits)
        year = format(payment.year, :two_digits)
        post['expiration-date'] = "#{month}/#{year}"
      end

      def add_references(post, options)
        post['merchant-id'] = @options[:merchant_id].to_s
        post['terminal-id'] = @options[:terminal_id].to_s
        post['idempotency-key'] = options[:authorization]
        post['token'] = options[:token]
        post['reference-number'] = options[:reference] if options[:reference]
      end

      def parse(body)
        begin
          JSON.parse(body)
        rescue StandardError
          [body.split(':')].to_h
        end
      end

      def commit(action, parameters)
        begin
          url = (test? ? test_url : live_url) + action
          response =
            parse(ssl_post(url, post_data(action, parameters), headers))
        rescue ResponseError => e
          response = parse(e.response.body)
        end

        Response.new(
          success_from(response, action),
          message_from(response, action),
          response,
          authorization: authorization_from(response),
          test: test?,
          error_code: error_code_from(response, action)
        )
      end

      def success_from(response, action)
        if action == '/idenpotency-keys'
          response.present?
        else
          response['response-code'] == '00'
        end
      end

      def message_from(response, action)
        if action == '/idenpotency-keys'
          response
        else
          if response['errors'].present?
            response['errors'].map { |e| "#{e['field']}: #{e['message']}" }.join
          else
            response['response-code-desc']
          end
        end
      end

      def authorization_from(response)
        response['ikey'] || response['approval-code'] ||
          response['idempotency-key']
      end

      def post_data(action, parameters = {})
        parameters.to_json
      end

      def error_code_from(response, action)
        unless success_from(response, action)
          response['internal-response-code'] ||
            response['errors'].to_a.map do |e|
              "#{e['field']}: #{e['message']}"
            end.join
        end
      end
    end
  end
end
