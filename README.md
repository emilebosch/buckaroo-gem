# Buckaroo ruby gem

This is a gem to allow buckaroo payments against BPE 3.0.

## Creating a payment request

First, request a payment.

```ruby
reponse = Buckaroo::Charge.create!(
  description: '10 thousand furbies',
  amount:1000,
  currency:'EUR'
)

throw 'Signature invalid' unless response.valid?

if response.require_redirect? redirect_to response.redirect_url
```

## Checking wheter a payment has succeeded

To check the reponse of

```ruby
class MyApp < Sinatra::Base
  post '/' do
    callback = Buckaroo::WebCallback.new(params)
    assert callback.valid?
  end
end
```