require 'spec_helper'

class Crud < Risky
  include Risky::ListKeys

  bucket :risky_crud
  value :value
end


describe 'CRUD' do
  it 'can create a new, blank object' do
    c = Crud.new
    c.key.should be_nil
    c.value.should be_nil
    c.save.should be_false
    c.errors[:key].should == 'is missing'
  end

  it 'can create and save a named object with a value' do
    # To be serialized in your best Nazgul voice
    c = Crud.new 'baggins', :value => 'shire!'
    c.key.should == 'baggins'
    c.value.should == 'shire!'
    c.save.should == c
  end

  it 'can read objects' do
    Crud['mary_poppins'].should be_nil

    # This rspec clone *IS* named after Francis Bacon, after all.
    c = Crud.new 'superstition', :value => 'confusion of many states'
    c.save.should_not be_false

    c2 = Crud['superstition']
    c2.should === c
    c2.value.should == 'confusion of many states'
  end

  it 'can test for existence' do
    Crud.exists?('russells_lagrangian_teapot').should be_false
    Crud.exists?('superstition').should be_true
  end

  it 'deletes an unfetched object' do
    Crud.delete('mary_poppins').should be_true
    Crud.delete('superstition').should be_true
  end

  it 'can delete a fetched object' do
    v = Crud.new('victim').save
    v.should_not be_false
    v.delete.should === v
    Crud.exists?(v).should be_false
  end

  it 'can compare objects' do
    a = Crud.new('superstition', 'value' => 'witches')
    b = Crud.new('superstition', 'value' => 'warlocks')
    a.should == b
    a.should === b
  end
end
