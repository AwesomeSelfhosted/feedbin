window.feedbin ?= {}

jQuery ->
  new feedbin.Registration()

class feedbin.Registration
  constructor: ->
    if typeof(Stripe) == "function"
      Stripe.setPublishableKey($('meta[name="stripe-key"]').attr('content'))
    $('#card_number').payment('formatCardNumber');
    $('#card_expiration').payment('formatCardExpiry');
    $('#card_code').payment('formatCardCVC');

    $(document).on 'change', '#card_month, #card_year', (event) ->
      $('#card_expiration').val("#{$('#card_month').val()} / #{$('#card_year').val()}")

    $(document).on 'submit', '[data-behavior~=credit_card_form]', (event) =>
      $('[data-behavior~=stripe_error]').addClass('hide')
      $('input[type=submit]').attr('disabled', true)
      if feedbin.applePay && @applePaySelected()
        @processApplePay()
        event.preventDefault()
      else if $('#card_number').length
        @processCard()
        event.preventDefault()
      else
        true

  applePaySelected: ->
    $('input[name=billing_method]').val() == "apple_pay"

  processApplePay: ->
    plan = $('input[name="user[plan_id]"]:checked').data()
    paymentRequest =
      countryCode: 'US'
      currencyCode: 'USD'
      total:
        label: "Feedbin #{plan.name} Subscription"
        amount: plan.amount

    console.log paymentRequest

    session = Stripe.applePay.buildSession paymentRequest, (result, completion) ->
      console.log result
      console.log completion

    session.oncancel = ->
      console.log 'cancel'

    session.begin()


  processCard: ->
    expiration = $('#card_expiration').payment('cardExpiryVal')
    card =
      number: $('#card_number').val()
      cvc: $('#card_code').val()
      expMonth: expiration.month
      expYear: expiration.year
    Stripe.createToken(card, @handleStripeResponse)

  handleStripeResponse: (status, response) ->
    if status == 200
      $('[data-behavior~=stripe_token]').val(response.id)
      $('[data-behavior~=credit_card_form]')[0].submit()
    else
      $('[data-behavior~=stripe_error]').removeClass('hide')
      if response.error.param == "exp_month" || response.error.param == "exp_year"
        message = "Your card's expiration date is invalid."
      else
        message = response.error.message
      $('[data-behavior~=stripe_error]').text(message)
      $('input[type=submit]').removeAttr('disabled')
