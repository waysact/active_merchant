require 'active_support/core_ext/hash/slice'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    # This gateway uses the current Stripe {Payment Intents API}[https://stripe.com/docs/api/payment_intents].
    # For the legacy API, see the Stripe gateway
    class StripePaymentIntentsGateway < StripeGateway

      self.supported_countries = %w(AT AU BE BR CA CH DE DK EE ES FI FR GB GR HK IE IT JP LT LU LV MX NL NO NZ PL PT SE SG SI SK US)

      ALLOWED_METHOD_STATES = %w[automatic manual].freeze
      ALLOWED_CANCELLATION_REASONS = %w[duplicate fraudulent requested_by_customer abandoned].freeze
      CREATE_INTENT_ATTRIBUTES = %i[description statement_descriptor receipt_email save_payment_method]
      CONFIRM_INTENT_ATTRIBUTES = %i[receipt_email return_url save_payment_method setup_future_usage off_session]
      UPDATE_INTENT_ATTRIBUTES = %i[description statement_descriptor receipt_email setup_future_usage]
      DEFAULT_API_VERSION = '2019-05-16'

      def create_intent(money, payment_method, options = {})
        post = {}
        add_amount(post, money, options, true)
        add_capture_method(post, options)
        add_confirmation_method(post, options)
        add_customer(post, options)
        add_payment_method_types(post, options)
        add_payment_method_token(post, payment_method, options)
        add_payment_method_data(post, payment_method, options)
        add_metadata(post, options)
        add_return_url(post, options)
        add_connected_account(post, options)
        add_shipping_address(post, options)
        setup_future_usage(post, options)
        add_exemption(post, options)

        CREATE_INTENT_ATTRIBUTES.each do |attribute|
          add_whitelisted_attribute(post, options, attribute)
        end

        commit(:post, 'payment_intents', post, options)
      end

      def commit(method, url, parameters = nil, options ={})
        add_expand_parameters(parameters, options) if parameters
        response = api_request(method, url, parameters, options)

        error = response["error"] || response["last_payment_error"]
        requires_action = response['status'] != 'succeeded' && response['capture_method'] == 'automatic'

        # If a card requires ThreeDS authorization but a payment redirect url is not set
        # the transaction will return with no errors (as there are no errors) but will require an action
        # to continue, this is ok when capturing manually, as the purchase is hold until the customer
        # authorizes it later, but when capturing automatically it will give the wrong perception that the
        # funds have been captured, thus we FAIL the transaction here if there are no errors + capture_method is
        # "automatic" + the status of the transaction is anything different than "succeeded".
        success = !(error || requires_action)

        card = card_from_response(response)
        avs_code = AVS_CODE_TRANSLATOR["line1: #{card["address_line1_check"]}, zip: #{card["address_zip_check"]}"]
        cvc_code = CVC_CODE_TRANSLATOR[card["cvc_check"]]

        error_message = response.dig("error", "message") || response.dig("last_payment_error", "message")
        error_message ||= response["status"].split("_").map(&:capitalize).join(" ") if requires_action

        Response.new(success,
          success ? "Transaction approved" : error_message,
          response,
          :test => response_is_test?(response),
          :authorization => authorization_from(success, url, method, response),
          :avs_result => { :code => avs_code },
          :cvv_result => cvc_code,
          :emv_authorization => emv_authorization_from_response(response),
          :error_code => success ? nil : error_code_from(response)
        )
      end

      def authorization_from(success, url, method, response)
        error_response = response["error"] || response["last_payment_error"]
        return error_response["charge"] if error_response

        if url == "customers"
          [response['id'], response.dig('sources', 'data').first&.dig('id')].join('|')
        elsif method == :post && (url.match(/customers\/.*\/cards/) || url.match(/payment_methods\/.*\/attach/))
          [response["customer"], response["id"]].join("|")
        else
          response["id"]
        end
      end

      def emv_authorization_from_response(response)
        error_response = response["error"] || response["last_payment_error"]
        return error_response["emv_auth_data"] if error_response

        card_from_response(response)["emv_auth_data"]
      end

      def error_code_from(response)
        error_response = response["error"] || response["last_payment_error"]
        return unless error_response

        code = error_response['code']
        decline_code = error_response['decline_code'] if code == 'card_declined'

        error_code = STANDARD_ERROR_CODE_MAPPING[decline_code]
        error_code ||= STANDARD_ERROR_CODE_MAPPING[code]
        error_code
      end

      def show_intent(intent_id, options)
        commit(:get, "payment_intents/#{intent_id}", nil, options)
      end

      def confirm_intent(intent_id, payment_method, options = {})
        post = {}
        add_payment_method_token(post, payment_method, options)
        CONFIRM_INTENT_ATTRIBUTES.each do |attribute|
          add_whitelisted_attribute(post, options, attribute)
        end

        commit(:post, "payment_intents/#{intent_id}/confirm", post, options)
      end

      def create_payment_method(payment_method, options = {})
        post = {}
        add_card_data(post, payment_method)
        add_billing_address(post, options)

        commit(:post, 'payment_methods', post, options)
      end

      def update_intent(money, intent_id, payment_method, options = {})
        post = {}
        post[:amount] = money if money

        add_payment_method_token(post, payment_method, options)
        add_payment_method_types(post, options)
        add_customer(post, options)
        add_metadata(post, options)
        add_shipping_address(post, options)
        add_connected_account(post, options)

        UPDATE_INTENT_ATTRIBUTES.each do |attribute|
          add_whitelisted_attribute(post, options, attribute)
        end

        commit(:post, "payment_intents/#{intent_id}", post, options)
      end

      def authorize(money, payment_method, options = {})
        create_intent(money, payment_method, options.merge!(confirm: true, capture_method: 'manual'))
      end

      def purchase(money, payment_method, options = {})
        create_intent(money, payment_method, options.merge!(confirm: true, capture_method: 'automatic'))
      end

      def capture(money, intent_id, options = {})
        post = {}
        post[:amount_to_capture] = money
        if options[:transfer_amount]
          post[:transfer_data] = {}
          post[:transfer_data][:amount] = options[:transfer_amount]
        end
        post[:application_fee_amount] = options[:application_fee] if options[:application_fee]
        commit(:post, "payment_intents/#{intent_id}/capture", post, options)
      end

      def void(intent_id, options = {})
        post = {}
        post[:cancellation_reason] = options[:cancellation_reason] if ALLOWED_CANCELLATION_REASONS.include?(options[:cancellation_reason])
        commit(:post, "payment_intents/#{intent_id}/cancel", post, options)
      end

      def refund(money, intent_id, options = {})
        intent = commit(:get, "payment_intents/#{intent_id}", nil, options)
        charge_id = intent.params.dig('charges', 'data')[0].dig('id')
        super(money, charge_id, options)
      end

      # Note: Not all payment methods are currently supported by the {Payment Methods API}[https://stripe.com/docs/payments/payment-methods]
      # Current implementation will create a PaymentMethod object if the method is a token or credit card
      # All other types will default to legacy Stripe store
      def store(payment_method, options = {})
        params = {}
        post = {}

        # If customer option is provided, create a payment method and attach to customer id
        # Otherwise, create a customer, then attach
        if payment_method.is_a?(StripePaymentToken) || payment_method.is_a?(ActiveMerchant::Billing::CreditCard)
          add_payment_method_token(params, payment_method, options)
          if options[:customer]
            customer_id = options[:customer]
          else
            post[:validate] = options[:validate] unless options[:validate].nil?
            post[:description] = options[:description] if options[:description]
            post[:email] = options[:email] if options[:email]
            customer = commit(:post, 'customers', post, options)
            customer_id = customer.params['id']
          end
          commit(:post, "payment_methods/#{params[:payment_method]}/attach", { customer: customer_id }, options)
        else
          super(payment, options)
        end
      end

      def unstore(identification, options = {}, deprecated_options = {})
        if identification.include?('pm_')
          _, payment_method = identification.split('|')
          commit(:post, "payment_methods/#{payment_method}/detach", nil, options)
        else
          super(identification, options, deprecated_options)
        end
      end

      private

      def add_card_data(post, payment_method)
        post[:type] = 'card'
        post[:card] = {}
        post[:card][:number] = payment_method.number
        post[:card][:exp_month] = payment_method.month
        post[:card][:exp_year] = payment_method.year
        post[:card][:cvc] = payment_method.verification_value if payment_method.verification_value
        post
      end

      def add_whitelisted_attribute(post, options, attribute)
        post[attribute] = options[attribute] if options[attribute]
        post
      end

      def add_capture_method(post, options)
        capture_method = options[:capture_method].to_s
        post[:capture_method] = capture_method if ALLOWED_METHOD_STATES.include?(capture_method)
        post
      end

      def add_confirmation_method(post, options)
        confirmation_method = options[:confirmation_method].to_s
        post[:confirmation_method] = confirmation_method if ALLOWED_METHOD_STATES.include?(confirmation_method)
        post
      end

      def add_customer(post, options)
        customer = options[:customer].to_s
        post[:customer] = customer if customer.start_with?('cus_')
        post
      end

      def add_return_url(post, options)
        return unless options[:confirm]
        post[:confirm] = options[:confirm]
        post[:return_url] = options[:return_url] if options[:return_url]
        post
      end

      def add_payment_method_data(post, payment_method, options)
        # for token and or string (eg: token) we don't add the card
        # details because we don't have them
        return if payment_method.is_a?(StripePaymentToken) || payment_method.is_a?(String)
        # Received both payment_method and payment_method_data parameters. Please pass in only one.
        # Stripe will return that error if both payment_method and payment_method_data
        # are present
        return if post[:payment_method].present?
        return unless options[:mit]

        post[:payment_method_data] = {}
        add_card_data(post[:payment_method_data], payment_method)
        post
      end

      def add_payment_method_token(post, payment_method, options)
        return if payment_method.nil?

        if payment_method.is_a?(ActiveMerchant::Billing::CreditCard)
          p = create_payment_method(payment_method, options)
          payment_method = p.params['id']
        end

        if payment_method.is_a?(StripePaymentToken)
          post[:payment_method] = payment_method.payment_data['id']
        elsif payment_method.is_a?(String)
          if payment_method.include?('|')
            customer_id, payment_method_id = payment_method.split('|')
            token = payment_method_id
            post[:customer] = customer_id
          else
            token = payment_method
          end
          post[:payment_method] = token
        end
      end

      def add_payment_method_types(post, options)
        payment_method_types = options[:payment_method_types] if options[:payment_method_types]
        return if payment_method_types.nil?

        post[:payment_method_types] = Array(payment_method_types)
        post
      end

      def add_exemption(post, options = {})
        return unless options[:confirm]
        post[:payment_method_options] ||= {}
        post[:payment_method_options][:card] ||= {}
        post[:payment_method_options][:card][:moto] = true if options[:moto]
        post[:payment_method_options][:card][:mit_exemption] ||= { claim_without_transaction_id: true } if options[:mit]
      end

      def setup_future_usage(post, options = {})
        post[:setup_future_usage] = options[:setup_future_usage] if %w( on_session off_session ).include?(options[:setup_future_usage])
        post[:off_session] = options[:off_session] if options[:off_session] && options[:confirm] == true
        post
      end

      def add_connected_account(post, options = {})
        return unless options[:transfer_destination]
        post[:transfer_data] = {}
        post[:transfer_data][:destination] = options[:transfer_destination]
        post[:transfer_data][:amount] = options[:transfer_amount] if options[:transfer_amount]
        post[:on_behalf_of] = options[:on_behalf_of] if options[:on_behalf_of]
        post[:transfer_group] = options[:transfer_group] if options[:transfer_group]
        post[:application_fee_amount] = options[:application_fee] if options[:application_fee]
        post
      end

      def add_billing_address(post, options = {})
        return unless billing = options[:billing_address] || options[:address]
        post[:billing_details] = {}
        post[:billing_details][:address] = {}
        post[:billing_details][:address][:city] = billing[:city] if billing[:city]
        post[:billing_details][:address][:country] = billing[:country] if billing[:country]
        post[:billing_details][:address][:line1] = billing[:address1] if billing[:address1]
        post[:billing_details][:address][:line2] = billing[:address2] if billing[:address2]
        post[:billing_details][:address][:postal_code] = billing[:zip] if billing[:zip]
        post[:billing_details][:address][:state] = billing[:state] if billing[:state]
        post[:billing_details][:email] = billing[:email] if billing[:email]
        post[:billing_details][:name] = billing[:name] if billing[:name]
        post[:billing_details][:phone] = billing[:phone] if billing[:phone]
        post
      end

      def add_shipping_address(post, options = {})
        return unless shipping = options[:shipping]
        post[:shipping] = {}
        post[:shipping][:address] = {}
        post[:shipping][:address][:line1] = shipping[:address][:line1]
        post[:shipping][:address][:city] = shipping[:address][:city] if shipping[:address][:city]
        post[:shipping][:address][:country] = shipping[:address][:country] if shipping[:address][:country]
        post[:shipping][:address][:line2] = shipping[:address][:line2] if shipping[:address][:line2]
        post[:shipping][:address][:postal_code] = shipping[:address][:postal_code] if shipping[:address][:postal_code]
        post[:shipping][:address][:state] = shipping[:address][:state] if shipping[:address][:state]

        post[:shipping][:name] = shipping[:name]
        post[:shipping][:carrier] = shipping[:carrier] if shipping[:carrier]
        post[:shipping][:phone] = shipping[:phone] if shipping[:phone]
        post[:shipping][:tracking_number] = shipping[:tracking_number] if shipping[:tracking_number]
        post
      end
    end
  end
end
