require 'spec_helper'
require 'risky/resolver'

Thread.abort_on_exception = true

class Multi < Risky
  include Risky::ListKeys
  include Risky::Resolver

  bucket :risky_mult
  allow_mult
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

def test(property, ins, out)
  it property do
    conflict(Multi, property, ins)[property].should == out
  end
end

def set_test(property, ins, out)
  it property do
    conflict(Multi, property, ins)[property].to_set.should == out.to_set
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
