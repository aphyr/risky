#!/usr/bin/env ruby

require 'rubygems'
require 'bacon'
require "#{File.expand_path(File.dirname(__FILE__))}/../lib/risky"

Bacon.summary_on_exit

class Indexed < Risky
  include Risky::Indexes

  self.riak = lambda { Riak::Client.new(:host => '127.0.0.1', :protocol => 'pbc') }
  
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
end
