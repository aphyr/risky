require 'spec_helper'

class Item < Risky
  include Risky::ListKeys

  bucket :risky_items
  value :v
end

class CronList < Risky
  include Risky::ListKeys
  include Risky::CronList

  bucket :risky_cron_list

  item_class Item
  limit 5
end


describe Risky::CronList do
  before :all do
    CronList.delete_all
    @l = CronList.new 'test'
  end

  it 'stores an item' do
    @l << {:v => 1}
    @l.items.first.should be_kind_of String
    Item[@l.items.first].should be_nil
    @l.save.should_not be_false

    @l.reload
    @l.items.size.should == 1
    @l.items.first.should be_kind_of String
    i = Item[@l.items.first]
    i.should be_kind_of Item
    i.v.should == 1
  end

  it 'limits items' do
    10.times do |i|
      @l << {:v => i}
    end
    @l.save.should_not be_false
    @l.reload
    @l.items.size.should == 5
    @l.items.map { |k|
      Item[k].v
    }.sort.should == (5...10).to_a
  end
end
