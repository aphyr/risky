#!/usr/bin/env ruby

require 'rubygems'
require 'bacon'
require "#{File.expand_path(File.dirname(__FILE__))}/../lib/risky"
require 'risky/queue'

Bacon.summary_on_exit

Risky.riak = proc { Riak::Client.new(:host => '127.0.0.1') }
Thread.abort_on_exception = true

class TestQueue < Risky
  bucket :queue

  include Risky::Queue
end

x = TestQueue.new
x.joins

describe 'Risky::Queue' do
  before do
    TestQueue.each { |x| x.delete }
  end

  should 'allow mult' do
    TestQueue.bucket.allow_mult.should == true
  end

  should 'join one member' do
    q = TestQueue.get_or_new('test')
    q.members.should.be.empty
    q.joins.should.be.empty

    q.join
    q.joins.should.be.empty
    q.members.keys.should == [q.id]
  end

  should 'join two members sequentially' do
    # Q1 joins
    q1 = TestQueue.get_or_new('test')
    q1.join.should == true
    q1.save

    # Q2 joins
    q2 = TestQueue.get_or_new('test')
    q2.handle
    q2.joins.should.be.empty
    q2.members.keys.should == [q1.id]
    q2.join_start
    q2.save
    
    # Q1 acknowledges
    q1.reload
    q1.handle
    q1.joins.size.should == 1
    q1.joins[q2.id]['ack'].sort.should == [q1.id, q2.id].sort
    q1.save

    # Q2 completes
    q2.reload
    q2.handle
    q2.should.join_acknowledged
    q2.join_complete
    q2.joins.should.be.empty
    q2.members.should.include? q1.id
    q2.members.should.include? q2.id
    q2.save

    # Q1 picks up
    q1.reload
    q1.handle
    q1.joins.should.be.empty
    q1.members.should.include? q1.id
    q1.members.should.include? q2.id
  end

  should 'join two members concurrently' do
    k = rand(100).to_s
    q1 = TestQueue.get_or_new(k)
    q2 = TestQueue.get_or_new(k)

    # Both join and save
    q1.join_start
    q2.join_start
    q1.save
    q2.save

    # Both pick up
    q1.reload
    q2.reload
    q1.handle
    q2.handle

    # Finalize joins
    q1.should.join_acknowledged
    q2.should.join_acknowledged
    q1.join_complete
    q2.join_complete

    # At this stage of the game both clients have only completed their own join.
    q1.members.should.include? q1.id
    q2.members.should.include? q2.id
    q1.should.joining
    q2.should.joining

    # The members list will be merged on the next reload, and joins cleaned up.
    q1.save
    q2.save
    q1.reload
    q2.reload
    q1.handle
    q2.handle
    q1.joins.should.be.empty
    q2.joins.should.be.empty
    q1.members.should == q2.members
    q1.members.should.include q1.id
    q2.members.should.include q2.id
  end 

  should 'part a lone member' do
    q = TestQueue.get_or_new('test')
    q.join.should == true

    q.part.should == true
    q.reload
    q.handle
    q.members.should.be.empty
    q.should.stable
  end

  should 'part one member from another' do
    q2 = TestQueue.get_or_new('test')
    q2.run do
      q1 = TestQueue.get_or_new('test')
      q1.join.should == true
      
      q1.part.should == true
      
      q2.lock.synchronize do
        q2.reload
        q2.handle
      end
      q2.members.keys.should == [q2.id]

      q2.save
      q1.reload
      q1.handle
      q1.members.keys.should == [q2.id]
      
      q1.should.stable
      q2.should.stable
    end
  end

  should 'join members' do
    threads = []
    queues = Set.new
  end
end
