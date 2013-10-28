require 'digest/sha1'
require 'rest_client'
require 'uri'

module Buckaroo

  class << self
    attr_accessor :key, :secret, :callback, :debug, :test
    def debug?; debug end;
    def test?; test; end;

    def execute!(hash, operation)
      nvp = hash.dup
      nvp['brq_websitekey'] = @key
      nvp['brq_signature'] = Hasher.calculate(nvp, @secret)

      if debug
        puts "------------------------"
        puts "=> Request: #{operation}"
        puts nvp.inspect
      end

      response_body = RestClient.post "#{gateway}?op=#{operation}", nvp

      h = URI.decode_www_form(response_body)

      reponse_hash = {}
      h.collect { |k| reponse_hash[k[0]] = k[1] }

      if debug
        puts
        puts "<= Response: #{operation}"
        puts reponse_hash.inspect
        puts "------------------------"
      end

      raise "Signature doesn't match" unless Hasher.valid?(reponse_hash, @secret)
      reponse_hash
    end

    def gateway
      return "https://testcheckout.buckaroo.nl/nvp/" if test?
      "https://testcheckout.buckaroo.nl/nvp/"
    end

    def status!(transaction_id)
      TransactionStatusResponse.new Buckaroo.execute!({'brq_transaction' => transaction_id}, 'transactionstatus')
    end

    def request_payment!(hash)

      request = {}
      request['brq_amount'] = '100.00'
      request['brq_currency'] = 'EUR'
      request['brq_invoicenumber'] = 'sasad'
      request['brq_description'] = 'test'
      request['brq_culture'] = 'nl-NL'

      request['brq_return'] = Buckaroo.callback
      request['brq_returncancel'] = Buckaroo.callback
      request['brq_returnerror'] = Buckaroo.callback
      request['brq_returnreject'] = Buckaroo.callback
      request['brq_continue_on_incomplete'] = 'RedirectToHTML'

      TransactionRequestResponse.new Buckaroo.execute!(request, 'transactionrequest')
    end

  end

  class Response

    def initialize(raw)
      @raw = raw
    end

    def raw
      @raw
    end

    def redirect_url
      raw['BRQ_REDIRECTURL']
    end

    def valid?
      raw['BRQ_STATUSCODE'] == '790'
    end

    def transaction
      raw['BRQ_TRANSACTIONS']
    end
  end

  class TransactionStatusResponse < Response
  end

  class TransactionRequestResponse < Response
  end

  class WebCallback
    def initialize(raw)
      @raw = raw
    end

    def valid?
      Hasher.valid? @raw, Buckaroo.secret
    end
  end

  class Hasher

    def self.valid?(hash, secret_key)
      raise ArgumentError, "Hasher: No hash given but '#{hash}'" unless hash.is_a?(Hash)
      raise ArgumentError, "Hasher: Secret key is not a string or not set #{secret_key}" unless secret_key.is_a?(String)

      name, signature = hash.find {|x,y| x.downcase == "brq_signature" }
      signature = hash.delete name

      computed = Hasher.calculate(hash, secret_key)
      computed == signature
    end

    def self.calculate(hash, secret_key)
      raise ArgumentError, "Hasher: No hash given but '#{hash}'" unless hash.is_a?(Hash)
      raise ArgumentError, "Hasher: Secret key is not as string or not set #{secret_key}" unless secret_key.is_a?(String)

      # 1. sort keys alphabetic
      # 2. concatonate to string
      # 3. add secet
      # 4. calculate RSA1

      x = hash.sort_by {|k, v| k.downcase.to_s }
      vars = x.collect{|k,v,| "#{k}=#{v}" }.join
      vars << secret_key

      Digest::SHA1.hexdigest vars
    end
  end
end