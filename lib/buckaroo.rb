require 'digest/sha1'
require 'rest_client'
require 'uri'

module Buckaroo

  class << self
    attr_accessor :key, :secret, :callback, :debug, :test
    def debug?; debug end;
    def test?; test; end;

    def execute!(hash, operation='transactionrequest')

      hash['brq_websitekey'] = @key
      hash['brq_signature'] = Hasher.calculate(hash, @secret)
      hash['op'] = operation

      p hash if debug?
      response_body = RestClient.post gateway, hash

      p response_body if debug?
      h = URI.decode_www_form(response_body)

      response = {}
      h.collect { |k| response[k[0]] = k[1] }

      given = response.delete 'BRQ_SIGNATURE'
      computed = Hasher.calculate(response, @secret)

      raise "Signature doesn't match" unless given == computed
      response
    end

    def gateway
      return "https://testcheckout.buckaroo.nl/nvp/" if test?
      "https://testcheckout.buckaroo.nl/nvp/"
    end
  end

  class WebCallback
    def initialize(raw)
      @raw = raw
    end

    def valid?
      Hasher.valid? @raw, Buckaroo.secret
    end
  end


  class Charge

    def initialize(hash)
    end

    def operation
      "transactionrequest"
    end

    def to_hash
      hash = {}
      hash['brq_amount'] = '100.00'
      hash['brq_currency'] = 'EUR'
      hash['brq_invoicenumber'] = 'sasad'
      hash['brq_description'] = 'test'
      hash['brq_culture'] = 'nl-NL'

      hash['brq_return'] = Buckaroo.callback
      hash['brq_returncancel'] = Buckaroo.callback
      hash['brq_returnerror'] = Buckaroo.callback
      hash['brq_returnreject'] = Buckaroo.callback

      hash['brq_continue_on_incomplete'] = 'RedirectToHTML'
      hash
    end

    def execute!
      res_hash = Buckaroo.execute!(to_hash, operation)
      ChargeResponse.new(res_hash)
    end

    def valid?
      true
    end

    class << self
      def create!(hash)
        charge = Charge.new(hash)
        charge.execute!
      end
    end
  end

  class ChargeResponse
    def initialize(raw)
      @raw = raw
    end

    def redirect_url
      @raw['BRQ_REDIRECTURL']
    end

    def valid?
      @raw['BRQ_STATUSCODE'] == '790'
    end
  end

  class Hasher

    def self.valid?(hash, secret_key)
      raise ArgumentError, "Hasher: No hash given but '#{hash}'" unless hash.is_a?(Hash)
      raise ArgumentError, "Hasher: Secret key is not a string or not set #{secret_key}" unless secret_key.is_a?(String)

      name, signature = hash.find {|x,y| x.downcase == "brq_signature" }
      signature = hash.delete name

      # FIXME: Hack because bucakroo is inconsistent in case conventions
      # and double decoding? - I AM NOT KIDDING!
      hack = true
      if hack
        a = {}
        hash.map { |k,v| a[k] = URI.decode_www_form_component(v) }
        hash = a
      end

      computed = Hasher.calculate(hash, secret_key)
      computed == signature
    end

    def self.calculate(hash, secret_key)
      raise ArgumentError, "Hasher: No hash given but '#{hash}'" unless hash.is_a?(Hash)
      raise ArgumentError, "Hasher: Secret key is not as string or not set #{secret_key}" unless secret_key.is_a?(String)

      # sort keys alphabetic
      # concatonate to string
      # add secet
      # calculate RSA1

      x = hash.sort_by {|k, v| k.downcase.to_s }

      vars = x.collect{|k,v,| "#{k}=#{v}" }.join
      vars << secret_key
      Digest::SHA1.hexdigest vars
    end
  end
end