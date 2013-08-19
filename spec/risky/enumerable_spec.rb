require 'spec_helper'

class Enum < Risky
  bucket :risky_enum
end

describe 'Enumerable' do
  before :all do
    # Wipe bucket and replace with 3 items
    Enum.delete_all

    @keys = ['hume', 'locke', 'spinoza']
    @keys.each do |key|
      Enum.new(key).save or raise
    end
  end

  it 'can count' do
    Enum.count.should == 3
  end

  it 'can list keys' do
    Enum.keys.should be_kind_of Array
    Enum.keys do |key|
      key.should be_kind_of String
    end
  end

  it 'can iterate' do
    seen = []
    Enum.each do |obj|
      obj.should be_kind_of Enum
      seen << obj.key
    end
    seen.sort.should == @keys
  end

  it 'can inject' do
    Enum.inject(0) do |count, obj|
      count + obj.key.size
    end.should == @keys.join('').size
  end
end
