require 'risky'

# Choose protocol/backend for riak connection
Risky.riak = Riak::Client.new(:host => '127.0.0.1')
# Risky.riak = Riak::Client.new(:host => '127.0.0.1', :http_backend => :Excon)
# Risky.riak = Riak::Client.new(:host => '127.0.0.1', :protocol => 'pbc')

Riak.disable_list_keys_warnings = true
