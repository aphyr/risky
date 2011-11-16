#!/usr/bin/env ruby

require File.expand_path("#{File.dirname(__FILE__)}/init.rb")

class Enum < Risky
  bucket 'enum'
end

describe 'Enumerable' do
  before do
    # Wipe bucket and replace with 3 items
    Enum.each { |x| x.delete }

    @keys = ['hume', 'locke', 'spinoza']
    @keys.each do |key|
      Enum.new(key).save or raise
    end
  end

  should 'count' do
    Enum.count.should == 3
  end

  should 'list keys' do
    Enum.keys.should.be.kind_of? Array
    Enum.keys do |key|
      key.should.be.kind_of? String
    end
  end

  should 'each' do
    seen = []
    Enum.each do |obj|
      obj.should.be.kind_of? Enum
      seen << obj.key
    end
    seen.sort.should == @keys
  end

  should 'inject' do
    Enum.inject(0) do |count, obj|
      count + obj.key.size
    end.should == @keys.join('').size
  end
end
