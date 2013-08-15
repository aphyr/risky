class User < Risky
  value :admin, :default => false
  bucket 'users'
end

describe 'Risky' do
  should 'have a bucket' do
    User.bucket.should.be.kind_of? Riak::Bucket
  end

  should 'store a value and retrieve it' do
    u = User.new('test', 'admin' => true)
    u.save.should.not.be.false

    u2 = User['test']
    u.key.should == 'test'
    u.admin.should == true
  end
end
