require 'spec_helper'

class User < Risky
  value :admin, :default => false
  value :age
  bucket 'users'
  allow_mult
end

describe 'Risky' do
  it 'has a bucket' do
    User.bucket.should be_kind_of Riak::Bucket
  end

  it 'can store a value and retrieve it' do
    u = User.new('test', 'admin' => true)
    u.save.should_not be_false

    u2 = User['test']
    u.key.should == 'test'
    u.admin.should == true
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
