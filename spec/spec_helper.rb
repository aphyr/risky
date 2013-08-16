require 'risky'

protocol = ENV['protocol'] || 'http'
Risky.riak = Riak::Client.new(:host => '127.0.0.1', :protocol => protocol)
Riak.disable_list_keys_warnings = true
