require 'risky'

Risky.riak = Riak::Client.new(:host => '127.0.0.1')
Riak.disable_list_keys_warnings = true
