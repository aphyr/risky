require 'spec_helper'

describe 'GZip' do
  class Zippable < Risky
    include Risky::GZip

    bucket :risky_gzip
    value :value
  end

  it 'can create and save a named object with a value' do
    g = Zippable.new 'pizzazz', :value => 'oomph'
    g.save.should == g
  end

  it 'can read objects' do
    Zippable['zest'].should be_nil

    g = Zippable.new 'zing', :value => 'vigor'
    g.save.should_not be_false

    g2 = Zippable['zing']
    g2.should === g
    g2.value.should == 'vigor'
  end
end

describe 'GZip with allow_mult' do
  class MultiZippable < Risky
    include Risky::GZip

    bucket :risky_gzip_mult
    allow_mult

    value :value

    def self.merge(versions)
      g = super(versions)
      g.value = versions.map(&:value).sort.join(', ')
      g
    end
  end

  it 'merges' do
    conflict(MultiZippable, 'value', ['spirit', 'sparkle']).value.should eq('sparkle, spirit')
  end
end

describe 'Legacy data not GZipped' do
  class NoZip < Risky
    bucket :risky_gzip_legacy
    value :value
  end

  class Zip < Risky
    include Risky::GZip

    bucket :risky_gzip_legacy
    value :value
  end

  it 'loads non-zipped legacy data' do
    g = NoZip.new 'gusto', :value => 'spritely'
    g.save.should == g

    g1 = Zip['gusto']
    g1.key.should eq(g.key)
    g1.value.should eq(g.value)
  end
end



