#!/usr/bin/env ruby

require File.expand_path("#{File.dirname(__FILE__)}/init.rb")

Risky.riak = lambda { Riak::Client.new(:host => '127.0.0.1') }

class Crud < Risky
  bucket 'crud'
  value :value
end

class Concurrent < Risky
  bucket 'concurrent'
  allow_mult
  value :v

  # Merge value v together as a list
  def self.merge(versions)
    p = super versions
    p.v = versions.inject([]) do |merged, version|
      merged + [*version.v]
    end.uniq
    p
  end
end

describe 'Threads' do
  should 'use a different client in each thread with lambdas' do
    clients = []
    (0..3).map do |i|
      Thread.new do
        clients << Risky.riak
      end
    end.each do |thread|
      thread.join
    end

    # Verify clients are distinct
    clients.uniq.should == clients
  end

  should 'support concurrent modification' do
    Concurrent.bucket.props['allow_mult'].should.be.true

    # Riak doesn't do well with concurrent *new* writes, so get an existing
    # value in there first.
    c = Concurrent.get_or_new('c')
    c.v = []
    c.save(:w => :all)

    workers = 10

    # Make a bunch of concurrent writes
    (0...workers).map do |i|
      Thread.new do
        # Give them a little bit of jitter, just to make the vclocks interesting
        sleep rand/6
        c = Concurrent.get_or_new('c')
        c.v << i
        c.save or raise
      end
    end.each do |thread|
      thread.join
    end

    # Check to ensure we obsoleted or have an extant write for every thread.
    final = Concurrent['c', {:r => :all}]
    final.v.compact.sort.should == (0...workers).to_a
  end
end
