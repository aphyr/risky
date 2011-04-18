#!/usr/bin/env ruby

require 'rubygems'
require 'bacon'
require "#{File.expand_path(File.dirname(__FILE__))}/../lib/risky"

Bacon.summary_on_exit

Risky.riak = Riak::Client.new(:host => '127.0.0.1')

class Crud < Risky
  bucket 'crud'

  value :value
end

describe 'CRUD' do
  should 'create a new, blank object' do
    c = Crud.new
    c.key.should.be.nil
    c.value.should.be.nil
    c.save.should.be.false
    c.errors[:key].should == 'is missing'
  end

  should 'create and save a named object with a value' do
    # To be serialized in your best Nazgul voice
    c = Crud.new 'baggins', :value => 'shire!'
    c.key.should == 'baggins'
    c.value.should == 'shire!'
    c.save.should == c
  end

  should 'read objects' do
    Crud['mary_poppins'].should.be.nil

    # This rspec clone *IS* named after Francis Bacon, after all.
    c = Crud.new 'superstition', :value => 'confusion of many states'
    c.save.should.not.be.false

    c2 = Crud['superstition']
    c2.should === c
    c2.value.should == 'confusion of many states'
  end

  should 'test for existence' do
    Crud.should.not.exists 'russells_lagrangian_teapot'
    Crud.should.exists 'superstition'
  end

  should 'delete an unfetched object' do
    Crud.delete('mary_poppins').should.be.nil
    Crud.delete('superstition').should.be.true
  end

  should 'delete a fetched object' do
    v = Crud.new('victim').save
    v.should.not.be.false
    v.delete.should === v
    Crud.should.not.exists v
  end

  should 'compare objects' do
    a = Crud.new('superstition', 'value' => 'witches')
    b = Crud.new('superstition', 'value' => 'warlocks')
    a.should === b
    a.should.not == b
  end
end
