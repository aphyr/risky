require 'spec_helper'

class Indexed < Risky
  include Risky::Indexes

  self.riak = lambda { |k| Riak::Client.new(:host => '127.0.0.1', :protocol => 'pbc') }

  bucket 'risky_indexes'

  value :value
  value :unique

  index :value
  index :unique, :unique => true
end


describe 'indexes' do
  before :all do
    Indexed.delete_all
  end

  it 'can index a string' do
    o = Indexed.new 'test', 'value' => 'value'
    o.save.should_not be_false
    Indexed.by_value('value').should === o
  end

  it 'can keep values unique (mostly)' do
    o = Indexed.new '1', 'unique' => 'u'
    o.save.should_not be_false

    o2 = Indexed.new '2', 'unique' => 'u'
    o2.save.should be_false
    o2.errors[:unique].should == 'taken'
  end
end
