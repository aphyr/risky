require 'spec_helper'
require 'risky/resolver'

Thread.abort_on_exception = true

class Multi < Risky

  bucket :risky_mult

  allow_mult

  include Risky::Resolver

  value :users, :default => []
  value :union, :resolve => :union
  value :intersection, :resolve => Risky::Resolver::Resolvers.method(:intersection)
  value :max, :resolve => :max
  value :min, :resolve => :min
  value :merge, :resolve => :merge
  value :custom, :resolve => lambda { |xs|
    :custom
  }

  def self.merge(v)
    p = super v

    p.users = v.map(&:users).min

    p
  end
end


# sorts array that have nil values (for Ruby 1.8.7)
def sort(ary)
  ary.sort { |a,b| ( a && b ) ? a <=> b : ( a ? 1 : -1 ) }
end

def conflict(field, values)
  key = rand(100000).to_s
  object = Multi.new(key).save

  # Create conflicting versions
  values.each_with_index.map do |value, i|
    Multi.riak.client_id = i + 1
    [Multi[key], value]
  end.each_with_index do |pair, i|
    o, value = pair
    Multi.riak.client_id = i + 1
    o[field] = value
    o.save
  end

  ro = Multi.bucket[key]
  ro.conflict?.should be_true
  begin
    sort(ro.siblings.map { |s| s.data[field] }).should == sort(values)
  rescue ArgumentError
    ro.siblings.map { |s| s.data[field] }.to_set.should == values.to_set
  end

  # Get all conflicts
  Multi[key, {:r => :all}]
end

def test(property, ins, out)
  it property do
    conflict(property, ins)[property].should == out
  end
end

def set_test(property, ins, out)
  it property do
    conflict(property, ins)[property].to_set.should == out.to_set
  end
end


describe Risky::Resolver do
  set_test 'union', [[1], [2]], [1,2]
  set_test 'union', [[1], nil], [1]
  set_test 'union', [[1,4,1], [2,3], [4,4]], [1,2,3,4]
  set_test 'intersection', [[1,2],[]], []
  set_test 'intersection', [[1,2,3,4], [1,2,3], [2,3,4]], [2,3]
  test 'min', [0,1,2,3], 0
  test 'max', [0,2,4,2], 4
  test 'max', [nil, nil], nil
  test 'max', [nil, 4], 4
  test 'custom', ['a', 'b', 'c'], :custom
end
