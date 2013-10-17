require 'risky'

# Choose protocol/backend for riak connection
# Risky.riak = Riak::Client.new(:host => '127.0.0.1')
# Risky.riak = Riak::Client.new(:host => '127.0.0.1', :http_backend => :Excon)
Risky.riak = Riak::Client.new(:host => '127.0.0.1', :protocol => 'pbc')

Riak.disable_list_keys_warnings = true

def sort(ary)
  ary.sort { |a,b| ( a && b ) ? a <=> b : ( a ? 1 : -1 ) }
end

def conflict(klass, field, values)
  key = rand(100000).to_s
  object = klass.new(key).save

  # Create conflicting versions
  values.each_with_index.map do |value, i|
    klass.riak.client_id = i + 1
    [klass[key], value]
  end.each_with_index do |pair, i|
    o, value = pair
    klass.riak.client_id = i + 1
    o[field] = value
    o.save
  end

  ro = klass.bucket[key]
  ro.conflict?.should be_true
  begin
    sort(ro.siblings.map { |s| s.data[field] }).should == sort(values)
  rescue ArgumentError
    ro.siblings.map { |s| s.data[field] }.to_set.should == values.to_set
  end

  # Get all conflicts
  klass[key, {:r => :all}]
end

