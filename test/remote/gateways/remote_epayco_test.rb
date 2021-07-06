require 'test_helper'

class RemoteEpaycoTest < Test::Unit::TestCase
  def setup
    @gateway = EpaycoGateway.new(fixtures(:epayco))

    @amount = 10_000_000

    @credit_card = credit_card('4575623182290326')
    @declined_card = credit_card('4151611527583283', { year: 2025, month: 12 })
    @failed_card = credit_card('5170394490379427', { year: 2025, month: 12 })
    @pending_card = credit_card('373118856457642', { year: 2025, month: 12 })

    @check = check(institution_number: '1022')

    @options = {
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
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Aceptada', response.message
    assert_equal '000000', response.authorization
  end

  def test_failed_purchase
    wrong_amount = 100
    response = @gateway.purchase(wrong_amount, @declined_card, @options)
    assert_failure response
    assert_equal 'Error create transaction', response.message
    assert_equal 'E014: La transacción no se puede iniciar, monto minimo no superado',
                 response.error_code
  end

  def test_failed_card_purchase
    response = @gateway.purchase(@amount, @failed_card, @options)
    assert_failure response
    assert_equal 'Fallida', response.message
    assert_equal 'Error de comunicación con el centro de autorizaciones',
                 response.error_code
  end

  def test_pending_purchase
    response = @gateway.purchase(@amount, @pending_card, @options)
    assert_success response
    assert_equal 'Pendiente', response.message
    assert_equal 'Transacción pendiente por validación', response.error_code
  end

  def test_blocked_card_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)

    assert_failure response
    assert_equal 'Rechazada', response.message
    assert_equal 'Tarjeta Bloqueada,comuniquese con el centro de autorizacion',
                 response.error_code
  end

  def test_pending_bank_purchase
    response = @gateway.purchase(@amount, @check, @bank_options)

    assert_success response
    assert_equal 'Pendiente', response.message
    assert_equal 'Redireccionando al banco', response.error_code
  end

  def test_failed_bank_purchase
    response = @gateway.purchase(@amount, check, @bank_options)
    assert_equal '500: field bank required', response.error_code
    assert_equal 'Error', response.message
  end

  def test_successful_bank_confirmation_status
    # Purchase with PSE information
    response = @gateway.purchase(@amount, @check, @bank_options)
    assert_equal 'Pendiente', response.message

    # Check status
    response = @gateway.bank_transaction_status(response.authorization)
    assert_equal 'Pendiente', response.message
  end

  def test_successful_information_gathering
    response = @gateway.get_financial_institutions

    assert_success response
    assert_equal 'Bancos consultados exitosamente PseController',
                 response.message
  end

  def test_transcript_scrubbing
    transcript =
      capture_transcript(@gateway) do
        @gateway.purchase(@amount, @credit_card, @options)
      end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@gateway.send(:base64_credentials), transcript)
    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
  end
end
