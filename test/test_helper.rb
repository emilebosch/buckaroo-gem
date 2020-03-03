require "buckaroo"
require "sinatra"
require "byebug"

Buckaroo.debug = ENV["DEBUG"]
Buckaroo.secret = ENV["BUCK_SECRET"]
Buckaroo.key = ENV["BUCK_KEY"]

raise "BUCK_SECRET not set in ENV" unless Buckaroo.secret
raise "BUCK_KEY not set in ENV" unless Buckaroo.key

require "minitest/autorun"
