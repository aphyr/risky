require 'spec_helper'

class User < Risky
  value :admin, :default => false
  bucket 'users'
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
end
