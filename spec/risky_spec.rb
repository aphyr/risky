require 'spec_helper'

class User < Risky
  include Risky::ListKeys

  bucket 'risky_users'
  allow_mult
  value :admin, :default => false
  value :age
end

describe 'Risky' do
  before :each do
    User.delete_all
  end

  it 'has a bucket' do
    User.bucket.should be_kind_of Riak::Bucket
  end

  it "can store a value and retrieve it" do
    user = User.new('test', 'admin' => true)
    user.save.should_not be_false

    user.key.should == 'test'
    user.admin.should == true
  end

  it "can find" do
    user = User.create('test')
    User.find('test').should == user
  end

  it "can find all by key" do
    user = User.create('test')
    User.find_all_by_key(['test']).should == [user]
  end

  it "returns id as integer" do
    user = User.new
    user.id = 1
    user.save
    user.id.should == 1
  end

  it "returns id as string" do
    user = User.new
    user.id = 'test'
    user.save
    user.id.should == 'test'
  end

  it "can update attribute" do
    user = User.new('test', 'admin' => true)
    user.update_attribute(:admin, false)
    user.admin.should be_false
  end

  it "can update attributes" do
    user = User.new('test', 'admin' => true)
    user.update_attributes({:admin => false})
    user.admin.should be_false
  end

  context "conflict resolution" do
    let(:key) { 'siblings' }

    before :each do
      User.new(key, 'age' => 20).save

      user1 = User[key]
      user2 = User[key]

      user1.age = 21
      user1.save

      # no conflict
      User.bucket.get(key).siblings.length.should == 1

      user2.age = 22
      user2.save

      # it creates a new sibling because of conflict
      User.bucket.get(key).siblings.length.should == 2
    end

    it 'it resolves the conflict on risky level' do
      user = User[key]
      User.bucket.get(key).siblings.length.should == 2
      user.riak_object.siblings.length.should == 1
    end

    it 'resolves the conflict on riak data level' do
      user = User[key]
      user.save
      user.riak_object.siblings.length.should == 1
      User.bucket.get(key).siblings.length.should == 1
    end
  end
end
