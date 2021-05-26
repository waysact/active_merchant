module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class EngagingNetworksGateway < Gateway
      include Empty

      self.live_url = 'https://e-activist.com'

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.supported_cardtypes = %i[
        visa
        master
        american_express
        discover
        diners_club
        jcb
      ]

      self.homepage_url = 'https://www.engagingnetworks.net/'
      self.display_name = 'Engaging Networks'

      STANDARD_ERROR_CODE_MAPPING = {}

      CARD_BRAND = {
        visa: 'VI',
        master: 'MC',
        american_express: 'AX',
        discover: 'DI',
        diners_club: 'DC',
        jcb: 'JC'
      }

      # options for this metadata should have keys in lowercase
      # as symbols, without punctuation, for example:
      # 'Get Involved - Membership' -> :get_involved_membership
      METADATA_QUESTIONS =
        [
          'Stay Informed - Nature News',
          'Get Involved - Advocacy',
          'Get Involved - Events',
          'Get Involved - Membership',
          'Get Involved - Volunteer',
          'Mobile Text Opt In',
          'Mobile Call Opt In',
          'Home Phone Opt In',
          'F2F-How do you identify',
          'F2F-How was your experience',
          'Tip Jar'
        ].map { |s| [s.gsub(/\W+/, '_').downcase.to_sym, s] }.to_h.freeze

      def initialize(options = {})
        requires!(options, :api_key)
        super
      end

      def purchase(amount, payment_method, options = {})
        MultiResponse.run do |r|
          r.process { authenticate }
          r.process do
            purchase_or_recurring(
              r.authorization,
              amount,
              payment_method,
              options,
              false
            )
          end
        end
      end

      def authenticate
        post = @options[:api_key]
        commit('auth', post)
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript.gsub(
            /[0-9a-f]{8}\b-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-\b[0-9a-f]{12}/i,
            '[FILTERED]'
          ).gsub(
            /(ens-auth-token: )([0-9a-f]{8}\b-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-\b[0-9a-f]{12})/i,
            '\1[FILTERED]'
          ) # the api_key is sent as the body
          .gsub(/("ccnumber\\?":\\?")[^"\\]*/i, '\1[FILTERED]')
          .gsub(/("ccvv\\?":\\?")\d+/, '\1[FILTERED]')
          .gsub(/("bankaccnum\\?":\\?")\d+/, '\1[FILTERED]')
          .gsub(/("bankrtenum\\?":\\?")\d+/, '\1[FILTERED]')
      end

      private

      # private
      #
      # build the data structure to send to EngagingNetworks.
      # it's important to note that this is more like a layer to
      # a CRM and a payment gateway, we treat it like others we've
      # implemented for customers
      def purchase_or_recurring(
        auth_token,
        amount,
        payment_method,
        options,
        recurring = false
      )
        # if processing a recurring plan, we need to ensure that
        # we receive the frequency
        requires!(options, :recurrfreq) if recurring

        post = {}

        options.merge!(ens_auth_token: auth_token)

        add_customer_data(post, options)
        add_payment_details(post, amount, payment_method, options)
        add_metadata(post, options)

        commit('sale', post, options)
      end

      # private
      #
      # adds the donor details
      def add_customer_data(post, options)
        customer = options[:customer]
        post['supporter'] =
          {
            "Email Address": email(options[:email], options),
            "First Name": customer[:first_name],
            "Last Name": customer[:last_name],
            "Birthday yyyy mm dd":
              (customer[:dob] unless empty?(customer[:dob])),
            "Mobile Phone": customer[:mobile_number],
            "Home Phone": customer[:home_phone],
            "questions": add_questions(options)
          }.merge(add_address(options))
      end

      # private
      #
      # generates an email placeholder with the format requested by the customer
      # if there's no donor email.
      #
      # Format: timestamp@fakeemail(custom_label).com
      def email(email, options)
        if email.blank?
          "#{Time.now.to_i}@fakeemail#{options[:email_label]}.com"
        else
          email
        end
      end

      # private
      #
      # `questions` is a whole set of metadata, more like a survey
      # however all the fields are hardcoded on the CRM side, thus
      # why we use the constant to hold them.
      def add_questions(options)
        options.select do |k, v|
          METADATA_QUESTIONS.values.include?(v)
        end.map { |k, v| [METADATA_QUESTIONS[k], v] }.to_h
      end

      # private
      #
      # adds the billing address of the donor, the field names are from BBCRM
      # and so they are named in a long a free-text way
      def add_address(options)
        address = options[:billing_address]

        post = {}
        post['Address 1'] = address[:address1] unless empty?(address[:address1])
        post['Address 2'] = address[:address2] unless empty?(address[:address2])
        post['City'] = address[:city] unless empty?(address[:city])
        post['State or Province'] = address[:state] unless empty?(
          address[:state]
        )
        post['ZIP or Postal Code'] = address[:zip] unless empty?(address[:zip])
        post['Country'] = address[:country] unless empty?(address[:country])

        post
      end

      # private
      #
      # builds the `transaction` block that contains the payment details
      # either CreditCard or Check (ACH). We also inform EngagingNetworks
      # if this is a recurring transaction or not, though for the purposes
      # of our implementation, we treat this as a one-of-transaction
      # like we did for other CRM-that-become-gateways :(
      def add_payment_details(post, amount, payment, options)
        txn = {
          "donationAmt": amount(amount),
          "recurrpay": empty?(options[:recurrfreq]) ? 'N' : 'Y',
          "recurrfreq": options[:recurrfreq]
        }
        payment_details =
          if payment.respond_to?(:routing_number)
            {
              "paymenttype": 'Check',
              "bankaccnum": payment.account_number,
              "bankrtenum": payment.routing_number,
              "bankacctype": payment.account_type
            }
          else
            {
              "paymenttype": CARD_BRAND[payment.brand.to_sym],
              "ccnumber": payment.number,
              "ccvv": payment.verification_value,
              "ccexpire":
                "#{format(payment.month, :two_digits)}#{format(payment.year, :two_digits)}"
            }
          end

        post['transaction'] =
          txn.merge(payment_details).delete_if { |_, v| v.blank? }
      end

      # private
      #
      # additional metadata
      def add_metadata(post, options)
        post['appealCode'] = options[:appealcode]
        post['txn7'] = options[:txn7]
      end

      # private
      def parse(body)
        JSON.parse(body)
      end

      # private
      def headers(options = {})
        # during the `authenticate` call, we don't yet have the
        # options[:ens_auth_token] set, so we remove that key if
        # that's the case
        {
          :'ens-auth-token' => options[:ens_auth_token],
          :'content-type' => 'application/json',
          'Accept-Encoding' => 'identity'
        }.delete_if { |k, v| v.blank? }
      end

      # private
      #
      # build the path to call
      def build_uri(action, options)
        case action
        when 'sale'
          "/ens/service/page/#{options[:page_id]}/process"
        when 'auth'
          '/ens/service/authenticate'
        end
      end

      # private
      def url(action, options)
        "#{self.live_url}#{build_uri(action, options)}"
      end

      # private
      #
      # send it all...
      def commit(action, parameters, options = {})
        parameters.merge!({ "demo": true }) if test? && action != 'auth'
        response =
          parse(
            ssl_post(
              url(action, options),
              post_data(action, parameters),
              headers(options)
            )
          )

        Response.new(
          success_from(action, response),
          message_from(action, response),
          response,
          authorization: authorization_from(action, response),
          test: test?,
          error_code: error_code_from(action, response)
        )
      rescue ResponseError => e
        case e.response.code
        when '401'
          return Response.new(false, 'Invalid credentials', {}, test: test?)
        end
      end

      # private
      def success_from(action, response)
        case action
        when 'auth'
          response.key?('ens-auth-token')
        else
          response['status'] == 'SUCCESS'
        end
      end

      # private
      def message_from(action, response)
        case action
        when 'auth'
          response['ens-auth-token']
        else
          if !success_from(action, response)
            response['error']
          else
            "#{response['status']}|#{response['type']}"
          end
        end
      end

      # private
      def authorization_from(action, response)
        case action
        when 'auth'
          response['ens-auth-token']
        else
          response['transactionId']
        end
      end

      # private
      #
      # the `auth` call wants the body to be a string and not a JSON
      # structure
      def post_data(action, parameters = {})
        case action
        when 'auth'
          parameters.to_s
        else
          parameters.to_json
        end
      end

      # private
      def error_code_from(action, response)
        response['error'] unless success_from(action, response)
      end
    end
  end
end
