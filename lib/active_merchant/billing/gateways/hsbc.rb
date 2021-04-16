module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class HsbcGateway < Gateway
      self.test_url = 'https://devcluster.api.p2g.netd2.hsbc.com.hk/cmb-connect-payments-pa-collection-cert-proxy/v1/direct-debits/'
      self.live_url = 'https://example.com/live' # TODO

      self.supported_countries = ['HK']
      self.default_currency = 'HKD'
      self.supported_cardtypes = []

      self.homepage_url = 'https://www.hsbc.com.hk/'
      self.display_name = 'HSBC'

      STANDARD_ERROR_CODE_MAPPING = {}

      def initialize(options={})
        requires!(options, :client_id, :client_secret, :profile_id, :public_key)
        super
      end

      def purchase(money, payment, options={})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, payment, options)
        add_customer_data(post, options)

        commit('sale', post)
      end

      def authorize(money, payment, options={})
        post = {}

        add_direct_debit_authorisation_data(post, money, options)
        add_creditor_account(post, options)

        commit('authorisations', post)
      end

      def capture(money, authorization, options={})
        commit('capture', post)
      end

      def refund(money, authorization, options={})
        commit('refund', post)
      end

      def void(authorization, options={})
        commit('void', post)
      end

      def verify(credit_card, options={})
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

      def add_invoice(post, money, options)
        post[:amount] = amount(money)
        post[:currency] = (options[:currency] || currency(money))
      end

      def add_payment(post, payment)
      end

      def add_direct_debit_authorisation_data(post, money, options)
        post["MerchantRequestIdentification"] = options[:merchant_request_identification]
        post["CreditorReference"] = options[:creditor_reference]
        post["DebtorName"] = options[:debtor_name]
        post["DebtorAccount"] = {
          "BankCode": options[:debtor_bank_code],
          "AccountIdentification": options[:account_identification],
          "Currency": 'HKD' # Only HKD is supported
        }
        post["CreditorName"] = options[:creditor_name]
        post["DebtorPrivateIdentification"] = options[:debtor_private_identification]
        post["DebtorPrivateIdentificationSchemeName"] = options[:debtor_private_identification_scheme_name]
        post["DebtorMobileNumber"] = options[:debtor_mobile_number]
        post["MaximumAmountCurrency"] = 'HKD' # Only HKD is supported
        post["MaximumAmount"] = amount(money)
        post["Occurrences"] = {
          # We're only supporting monthly direct debit right now
          "FrequencyType": 'MNTH',
          # And they don't expire - it's another system's job to cancel them
          "DurationToDate": '9999-12-31'
        }
      end

      def add_creditor_account(post, options)
        post["CreditorAccount"] = {
          "BankCode": options[:creditor_bank_code],
          "AccountIdentification": options[:account_identification],
          "Currency": 'HKD' # Only HKD is supported
        }
      end

      def parse(body)
        JSON.parse(body)
      end

      def commit(action, parameters)
        url = (test? ? test_url : live_url) + action
        begin
          response = parse(ssl_post(url, post_data(action, parameters), headers))
        rescue ActiveMerchant::ResponseError => e
          response = parse(e.response.body)
        end

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          avs_result: AVSResult.new(code: response["some_avs_response_key"]),
          cvv_result: CVVResult.new(response["some_cvv_response_key"]),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def headers
        {
          'x-hsbc-country-code': 'HK', # Hong Kong is the only supported country
          'x-hsbc-client-id': @options[:client_id],
          'x-hsbc-client-secret': @options[:client_secret],
          'x-hsbc-profile-id': @options[:profile_id],
        }
      end

      def success_from(response)
        response['error'].nil? && response['Errors'].nil?
      end

      def message_from(response)
        response['description'] || response['Message'] # TODO: Process success
      end

      def authorization_from(response)
      end

      def post_data(action, parameters = {})
      end

      def error_code_from(response)
        unless success_from(response)
          # TODO: lookup error code for this response
        end
      end
    end
  end
end
