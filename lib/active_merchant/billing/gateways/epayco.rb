module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class EpaycoGateway < Gateway
      self.test_url = 'https://apify.epayco.co'
      self.live_url = 'https://apify.epayco.co'

      self.supported_countries = ['CO']
      self.default_currency = 'COP'
      self.supported_cardtypes = %i[visa master american_express discover]

      self.homepage_url = 'https://api.epayco.co'
      self.display_name = 'ePayco'

      STANDARD_ERROR_CODE_MAPPING = {}

      BANK_ENDPOINTS = %w[
        /payment/pse/banks
        /payment/process/pse
        /payment/pse/transaction
      ]

      def initialize(options = {})
        requires!(options, :public_key, :private_key)
        super
      end

      def purchase(money, payment, options = {})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment, options)
        add_address_data(post, options)
        add_customer_data(post, options)

        post[:urlResponse] = options[:url_response] if options.key?(
          :url_response
        )

        add_misc_data(post, options)

        endpoint =
          if payment.is_a?(CreditCard)
            '/payment/process'
          else
            '/payment/process/pse'
          end
        commit(endpoint, post)
      end

      def bank_transaction_status(authorization)
        commit('/payment/pse/transaction', { transactionID: authorization })
      end

      def get_financial_institutions
        commit('/payment/pse/banks', nil, :get)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript
          .gsub(/(Authorization:\s+Basic\s+)\w+(.+)/, '\1[FILTERED]\2')
          .gsub(/(Authorization: Bearer )([A-Za-z0-9\-\._~\+\/]+=*)/, '\1[FILTERED]')
          .gsub(/({\\?{3}"token\\?{3}\":)\S+(})/, '\1[FILTERED]\2')
          .gsub(/(cardNumber\\?{3}\":\\?{3}\")\d+/, '\1[FILTERED]')
          .gsub(/(cardCvc\\?{3}\":\\?{3}\")\d+/, '\1[FILTERED]')
      end

      private

      def add_customer_data(post, options)
        post[:docType] = options.fetch(:client_id_type)
        post[:docNumber] = options.fetch(:client_id_number)
        post[:name] = options.fetch(:first_name)
        post[:email] = options.fetch(:email)
        post[:cellPhone] = options.fetch(:mobile_phone)
        post[:phone] = options.fetch(:phone)
        post[:ip] = options.fetch(:ip)

        # 0 - Persona
        # 1 - Comercio
        post[:typePerson] = options.fetch(:person_type, 0)

        post[:lastName] = options.fetch(:last_name) if options.key?(:last_name)
        if options.key?(:customer_id)
          post[:customerId] = options.fetch(:customer_id)
        end
      end

      def add_address_data(post, options)
        post[:address] = options.dig(:address, :address1)
      end

      def add_invoice(post, money, options)
        post[:value] = amount(money)
        post[:currency] = (options[:currency] || currency(money))
        post[:dues] = options.fetch(:dues, '1')
        post[:tax] = options[:tax] if options.key?(:tax)
        post[:taxBase] = options[:tax_base] if options.key?(:tax_base)
        post[:description] = options[:description] if options.key?(:description)
        post[:invoice] = options[:invoice] if options.key?(:invoice)
      end

      def add_payment(post, payment, options)
        if payment.is_a?(CreditCard)
          post[:cardNumber] = payment.number
          post[:cardExpMonth] = payment.month.to_s.rjust(2, '0')
          post[:cardExpYear] = payment.year.to_s
          post[:cardCvc] = payment.verification_value if payment
            .verification_value?
        elsif options.key?(:bank_id)
          post[:bank] = options[:bank_id]
        else
          post[:cardTokenId] = payment
        end
      end

      def add_misc_data(post, options)
        post[:urlConfirmation] = options[:url_confirmation] if options.key?(
          :url_confirmation
        )

        (1..10).each do |i|
          key = "extra#{i}".to_sym
          post[key] = options[key] if options.key?(key)
        end

        post[:methodConfimation] = options[:method_confirmation] || 'GET'
      end

      def parse(body)
        JSON.parse(body)
      end

      def headers(header_type, token)
        {
          'Authorization' => header_type + ' ' + token,
          'Content-Type' => 'application/json'
        }
      end

      def commit(action, parameters, method = :post)
        url = (test? ? test_url : live_url) + action
        data = post_data(action, parameters)
        response =
          parse(ssl_request(method, url, data, headers('Bearer', access_token)))

        Response.new(
          success_from(action, response),
          message_from(action, response),
          response,
          authorization: authorization_from(action, response),
          test: test?,
          error_code: error_code_from(action, response)
        )
      end

      def authorization_token(token_type)
        token_type == 'Bearer' ? bearer_token : basic_token
      end

      def success_from(action, response)
        if BANK_ENDPOINTS.include?(action)
          response['success']
        else
          transaction_status = transaction_data(response)['estado']
          %w[Aceptada Pendiente].include?(transaction_status)
        end
      end

      def message_from(action, response)
        if action == '/payment/pse/banks'
          response['textResponse']
        else
          data = transaction_data(response)
          data['estado'] || data['respuesta'] || response['titleResponse'] ||
            response['textResponse']
        end
      end

      def authorization_from(action, response)
        case action
        when '/login'
          response['token']
        when '/payment/pse/banks'
          nil
        else
          transaction_data(response)['autorizacion']
        end
      end

      def post_data(action, parameters = {})
        parameters.to_json unless parameters.nil?
      end

      def error_code_from(action, response)
        return if action == '/payment/pse/banks'

        response_data = response['data'] || {}

        if response_data.dig('transaction', 'success')
          response_data.dig('transaction', 'data', 'respuesta')
        elsif response_data['estado'] == 'Pendiente'
          response_data.dig('respuesta')
        else
          extract_errors(response_data)
        end
      end

      def extract_errors(data)
        errors = data.dig('errors') || data.dig('error', 'errors') || {}

        errors.map { |e| "#{e['codError']}: #{e['errorMessage']}" }.join(' ')
      end

      def transaction_data(response)
        if response['data'].is_a?(Array)
          response['data']
        else
          response.dig('data', 'transaction', 'data') || response['data']
        end
      end

      def credentials
        @options[:public_key] + ':' + @options[:private_key]
      end

      def base64_credentials
        Base64.strict_encode64(credentials)
      end

      def access_token
        url = (test? ? test_url : live_url) + '/login'
        raw_response = ssl_post(url, ' ', headers('Basic', base64_credentials))

        get_token(parse(raw_response))
      end

      def get_token(response)
        response.fetch('token', nil)
      end
    end
  end
end
