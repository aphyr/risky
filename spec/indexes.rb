#!/usr/bin/env ruby

require 'rubygems'
require 'bacon'
require "#{File.expand_path(File.dirname(__FILE__))}/../lib/risky"

Bacon.summary_on_exit

class Indexed < Risky
  include Risky::Indexes

  self.riak = lambda { |k| Riak::Client.new(:host => '127.0.0.1', :protocol => 'pbc') }
  
  bucket 'indexes'
  value :value
  value :unique

  index :value
  index :unique, :unique => true
end

describe 'indexes' do
  before do
    Indexed.each { |x| x.delete }
  end

  should 'index a string' do
    o = Indexed.new 'test', 'value' => 'value'
    o.save.should.not.be.false
    Indexed.by_value('value').should === o
  end

  should 'keep values unique (mostly)' do
    o = Indexed.new '1', 'unique' => 'u'
    o.save.should.not.be.false

    o2 = Indexed.new '2', 'unique' => 'u'
    o2.save.should.be.false
    o2.errors[:unique].should == 'taken'
  end
end
