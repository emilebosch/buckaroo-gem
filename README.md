# Buckaroo ruby gem

[![Build Status](http://drone.hoppinger.com/api/badges/hoppinger/buckaroo/status.svg)](http://drone.hoppinger.com/hoppinger/buckaroo)

This is a gem to allow buckaroo payments against BPE 3.0. Its right now under development
but will be released in the next couple of days.

### How to use

It's easy!

```
gem install buckaroo
```

Or add it to your `Gemfile`

#### Setting up your key

First start by setting up your keys:

```
Buckaroo.debug  = true
Buckaroo.secret = ENV['BUCK_SECRET']
Buckaroo.key = ENV['BUCK_KEY']
```

Use ``rbenv-vars`` to ease your pain.

#### Creating a payment request

First, let's request a payment, and redirect the user to the payment gatway.

```
reponse = Buckaroo::Charge.create!(
  description: 'ten thousand furbies',
  amount:1000,
  currency:'EUR'
)

throw 'Signature invalid' unless response.valid?

if response.require_redirect? redirect_to response.redirect_url
```

#### Checking wheter a payment has succeeded after a redirect from Buckaroo

To check the information being send back from the gateway, you can use the ``Buckaroo::WebCallback`` to process the response.

```
class MyApp < Sinatra::Base
  post '/' do
    callback = Buckaroo::WebCallback.new(params)
    assert callback.valid?
  end
end
```

### Test

Buckaroo comes with a sweet test suite. It comes with some basic tests, and a full integration test using ``phantomjs`` against the buckaroo gateway.

Type the following to do the tests (IT WILL DO AN ACTUAL TEST PAYMENT TO BUCKAROO):

```
rake test
```

Under the hood it uses, `phantomjs`, `sinatra` and `capybara` to test the functionality end to end.


#### SSH push reverse proxy
