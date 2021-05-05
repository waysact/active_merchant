require 'tmpdir'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class HsbcGateway < Gateway
      self.test_url = 'https://devcluster.api.p2g.netd2.hsbc.com.hk/cmb-connect-payments-pa-collection-cert-proxy/v1/direct-debits/'
      self.live_url = 'https://example.com/live' # TODO

      self.supported_countries = ['HK']
      self.default_currency = 'HKD'
      self.supported_cardtypes = []

      self.money_format = :cents

      self.homepage_url = 'https://www.hsbc.com.hk/'
      self.display_name = 'HSBC'

      STANDARD_ERROR_CODE_MAPPING = {}

      def initialize(options={})
        requires!(options, :client_id, :client_secret, :profile_id, :public_key)
        super
      end

      def authorize(money, payment, options={})
        post = {}

        add_direct_debit_authorisation_data(post, money, options)

        commit('authorisations', post)
      end

      def authorize_confirmation(options={})
        post = {}

        add_otp_confirmation_data(post, options)

        commit('authorisations/otp-confirmation', post)
      end

      def authorize_otp_regeneration(options={})
        post = {}

        add_otp_regeneration_data(post, options)

        commit('authorisations/otp-regeneration', post)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.
          gsub(/(X-Hsbc-Client-Id: )([A-Za-z0-9]{32})/i, '\1[FILTERED]').
          gsub(/(X-Hsbc-Client-Secret: )([A-Za-z0-9]{32})/i, '\1[FILTERED]')
      end

      private

      def add_otp_confirmation_data(post, options)
        post["MandateIdentification"] = options[:mandate_identification]
        add_creditor_account(post, options)
        post["OtpIdentificationNumber"] = options[:otp_identification_number]
        post["OtpPassword"] = options[:otp_password]
      end

      def add_direct_debit_authorisation_data(post, money, options)
        post["MerchantRequestIdentification"] = options[:merchant_request_identification]
        post["CreditorReference"] = options[:creditor_reference]
        post["DebtorName"] = options[:debtor_name]
        post["DebtorAccount"] = {
          "BankCode": options[:debtor_bank_code],
          "AccountIdentification": options[:account_identification],
          "Currency": 'HKD', # Only HKD is supported
          "AccountSchemeName": 'BBAN', # Only value supported
        }
        post["CreditorName"] = options[:creditor_name]
        add_creditor_account(post, options)
        post["DebtorPrivateIdentification"] = options[:debtor_private_identification]
        post["DebtorPrivateIdentificationSchemeName"] = options[:debtor_private_identification_scheme_name]
        post["DebtorMobileNumber"] = options[:debtor_mobile_number]
        post["MaximumAmountCurrency"] = 'HKD' # Only HKD is supported
        post["MaximumAmount"] = amount(money)
        post["Occurrences"] = {
          # We're only supporting monthly direct debit right now
          "FrequencyType": 'MNTH',
          # And they don't expire - it's another system's job to cancel them
          "DurationToDate": '9999-12-31',
        }
        post["OtpHoldIndicator"] = false
        post["SmsLanguageCode"] = "eng"
      end

      def add_otp_regeneration_data(post, options)
        post["MandateIdentification"] = options[:mandate_identification]
        add_creditor_account(post, options)
        post["SmsLanguageCode"] = "eng"
      end

      def add_creditor_account(post, options)
        post["CreditorAccount"] = {
          "BankCode": options[:creditor_bank_code],
          "AccountIdentification": options[:creditor_account_identification],
          "Currency": 'HKD', # Only HKD is supported
          "AccountSchemeName": 'BBAN', # Only value supported
        }
      end

      def parse(body)
        JSON.parse(body)
      end

      def encrypt_and_sign(plaintext)
        gpg_operations(:encrypt_and_sign, plaintext)
      end

      def decrypt_and_verify(ciphertext)
        gpg_operations(:decrypt_and_verify, ciphertext)
      end

      def gpg_operations(operation, payload)
        payload_io = StringIO.new payload
        output_filename = SecureRandom.hex(16)
        output_path = Dir.mktmpdir
        output_file = File.join(output_path, output_filename)
        ActiveMerchant::Crypto.send(operation, payload_io, output_file, @options[:public_key], @options[:private_key])
        File.read(output_file)
      ensure
        # remove the temporary directory we created
        begin
          FileUtils.remove_entry_secure output_path
        rescue Errno::ENOENT # rubocop:disable Lint/HandleExceptions
          # ignore
        end
      end

      def encode_payload(payload)
        Base64.strict_encode64(payload.to_s)
      end

      def decode_payload(payload)
        Base64.strict_decode64(payload)
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
          'content-type': 'application/json',
        }
      end

      def success_from(response)
        response['error'].nil? && response['Errors'].nil?
      end

      def message_from(response)
        if success_from(response)
          ciphertext = decode_payload(response['ResponseBase64'])
          parse(decrypt_and_verify(ciphertext))
        else
          "#{response['Id']} #{response['Code']} #{response['Message']}"
        end
      end

      def authorization_from(response)
        if success_from(response)
          plaintext_response = message_from(response)
          
          plaintext_response['MandateIdentification']
        end
      end

      def post_data(action, parameters = {})
        {
          RequestBase64: encode_payload(
            encrypt_and_sign(parameters.to_json.to_s)
          )
        }.to_json
      end

      def error_code_from(response)
        unless success_from(response)
          # TODO: lookup error code for this response
        end
      end
    end
  end
end
