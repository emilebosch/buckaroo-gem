require 'digest/sha1'
require 'rest_client'
require 'uri'
require 'log4r'

module Buckaroo

  class << self

    attr_accessor :key, :secret, :callback, :debug, :test, :push, :log
    def debug?; debug end;
    def test?; test; end;

    def execute!(hash, operation)
      self.log = Log4r::Logger.new('log')
      log.outputters << Log4r::StdoutOutputter.new('log_stdout')

      nvp = hash.dup
      nvp['brq_websitekey'] = @key
      nvp['brq_signature'] = Hasher.calculate(nvp, @secret)

      if debug
        log.debug "------------------------"
        log.debug "=> Request: #{operation}"
        log.debug nvp.inspect
      end

      response_body = RestClient.post "#{gateway}?op=#{operation}", nvp
      h = URI.decode_www_form(response_body)

      reponse_hash = {}
      h.collect { |k| reponse_hash[k[0]] = k[1] }

      if debug
        log.debug ""
        log.debug "<= Response: #{operation}"
        log.debug reponse_hash.inspect
        log.debug "------------------------"
      end

      raise "Signature doesn't match" unless Hasher.valid?(reponse_hash, @secret)
      reponse_hash
    end

    def status!(transaction_id)
      TransactionStatusResponse.new Buckaroo.execute!({'brq_transaction' => transaction_id}, 'transactionstatus')
    end

    def request_payment!(hash)

      throw 'amount needs to be set' unless hash[:amount]
      throw 'invoice_number' unless hash[:invoice_number]
      throw 'description' unless hash[:description]

      request = {}

      request['brq_currency'] = 'EUR'
      request['brq_requestedservices'] = hash[:requested_services].join(',')
      request['brq_culture'] = 'en-EN'
      request['brq_continue_on_incomplete'] = 'RedirectToHTML'

      request['brq_push'] = Buckaroo.push if Buckaroo.push
      request['brq_pushfailure'] = Buckaroo.push if Buckaroo.push

      request['brq_amount'] = hash[:amount]
      request['brq_invoicenumber'] = hash[:invoice_number]
      request['brq_description'] = hash[:description]
      request['brq_return'] = hash[:return_url] || Buckaroo.callback

      TransactionRequestResponse.new Buckaroo.execute!(request, 'transactionrequest')
    end

    def gateway
      return "https://testcheckout.buckaroo.nl/nvp/" if test?
      "https://checkout.buckaroo.nl/nvp/"
    end
  end

  class Response

    def initialize(raw)
      @raw = raw
    end

    def raw
      @raw
    end

    def status
      raw['BRQ_STATUSCODE'].to_i
    end

    def redirect_url
      raw['BRQ_REDIRECTURL']
    end

    def pending_input?
      status_code = 790
    end

    def pending_processing?
      status_code = 791
    end

    def invoice_number
      raw['BRQ_INVOICENUMBER']
    end

    def amount
      raw['BRQ_AMOUNT']
    end

    def awaiting_consumer?
      status_code = 792
    end

    def valid?
      Hasher.valid? raw, Buckaroo.secret
    end

    def on_hold?
      status_code = 793
    end

    def transaction
      raw['BRQ_TRANSACTIONS']
    end
  end

  class TransactionStatusResponse < Response
  end

  class TransactionRequestResponse < Response
  end

  class WebCallback < Response
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
