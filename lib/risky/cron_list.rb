module Risky::CronList
  # Provides methods which allow a Risky model to act as a chronological list
  # of references to some other model.
  
  module ClassMethods
    def item_class(klass = nil)
      if klass
        @item_class = klass
      else
        @item_class or raise "no item class defined for #{self}"
      end
    end

    def limit(limit = nil)
      if limit
        @limit = limit
      else
        @limit
      end
    end

    def merge(versions)
      # Order versions chronologically
      p = super(versions)
      items = sort_items(
        versions.inject([]) do |list, version|
          list |= version.items.reverse
        end.reverse
      )

      if limit = self.limit
        p.items = items[0...limit]
        p.removed_items = items[limit..-1] || []
      else
        p.items = items
      end

      p
    end

    # Sorts a list of items into the appropriate order.
    def sort_items(items)
      items.sort { |a,b| b <=> a }
    end
  end

  def self.included(base)
    base.value :items, :default => []
    base.extend ClassMethods
  end

  def initialize(*a)
    super *a

    @added_items ||= []
    @removed_items ||= []
  end

  def <<(item)
    if self.class.item_class === item
      # Item is already an object; ensure it has a key.
      item.key ||= new_item_key(item)
    else
      # Create a new item with <item> as the data.
      item = self.class.item_class.new(new_item_key(item), item)
    end

    add_item item

    trim
  end
  alias :add :<<

  def add_item(item)
    @added_items << item
    @removed_items.delete item.key 

    unless items.include? item.key
      items.unshift item.key

      if self.class.sort_items(items[0,2]).first != item.key
        # We must reorder.
        self.items = self.class.sort_items(items)
      end
    end
  end

  def added_items
    @added_items
  end

  def added_items=(items)
    @added_items = items
  end

  def after_delete
    super

    (@removed_items + items).each do |item|
      delete_item(item) rescue nil
    end

    @removed_items.clear
  end

  def after_save
    super
    
    @removed_items.each do |item|
      delete_item(item) rescue nil
    end

    @added_items.clear
    @removed_items.clear
  end

  def all
    items.map { |item| self.class.item_class[item] }
  end

  def before_save
    super

    @added_items.each do |item|
      item.save(:w => :all) or raise "unable to save #{item}"
    end
  end

  # Remove all items. Items will actually be deleted on #save
  def clear
    @removed_items += items
    items.clear
  end

  # Remove dangling references. Items will actually be deleted on #save
  # TODO...
  #def cleanup
  #end

  # Remove an item by key.
  def remove(item_key)
    if key = items.delete(item_key)
      # This item existed.
      @added_items.reject! do |item|
        item['key'] == item_key
      end

      @removed_items << key
    end

    key
  end

  # Takes an entry of items and deletes it.
  def delete_item(item)
    self.class.item_class.delete item
  end

  # Generates a key for a newly added item.
  def new_item_key(item = nil)
    # Re-use existing time
    begin
      t = item['created_at']
      if t.kind_of? String
        time = Time.iso8601(t)
      elsif t.kind_of? Time
        time = t
      end
    rescue
    end
    time ||= Time.now
     
    "k#{key}_t#{time.to_f}#{rand(10**5)}"
  end

  def removed_items
    @removed_items
  end

  def removed_items=(items)
    @removed_items = items
  end

  def trim
    # Remove expired items
    if limit = self.class.limit
      if removed = items.slice!(limit..-1)
        @removed_items += removed
      end
    end

    self
  end
end
