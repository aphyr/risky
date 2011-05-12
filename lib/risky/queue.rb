module Risky::Queue
  # Yo dawg, we put a ring in your ring so you can work while you work.
  #
  # This module, when included, allows a model to act as a queue of items for
  # multiple readers. It guarantees:
  #
  # 1. No items will be lost.
  # 2. Items will be processed in roughly sequential order.

  JOIN_INTERVAL = 4
  PART_INTERVAL = 10
  RUN_INTERVAL = 2

  module ClassMethods
    def merge(versions)
      p = super(versions)

      # Choose the most recent data for each member
      members = versions.inject({}) do |members, version|
        version.members.each do |id, data|
          if !members.include?(id) or members[id]['time'] < data['time']
            members[id] = data
          end
        end
        members
      end

      # Merge together all joins.
      joins = versions.inject({}) do |joins, version|
        version.joins.each do |id, join|
          if joins.include? id
            # Merge acknowledgements
            joins[id]['ack'] |= join['ack']
          else
            joins[id] = join
          end
        end
        joins
      end
      
      # Merge together all parts.
      parts = versions.inject({}) do |parts, version|
        version.parts.each do |id, part|
          if parts.include? id
            # Merge acknowledgements
            parts[id]['ack'] |= part['ack']
          else
            parts[id] = part
          end
        end
        parts
      end

      # Merge all free items
      free = versions.inject({}) do |free, version|
        free.merge(version.free)
      end

      # Merge all taken items
      taken = versions.inject({}) do |taken, version|
        taken.merge(version.taken)
      end

      p.joins = joins
      p.members = members
      p.parts = parts

      p.free = free
      p.taken = taken

      p
    end
  end

  def self.included(base)
    base.extend ClassMethods

    base.allow_mult

    base.value :joins, :default => {}
    base.value :members, :default => {}
    base.value :parts, :default => {}

    base.value :free, :default => {}
    base.value :taken, :default => {}
  
    base.instance_eval do
      attr_writer :id
      attr_writer :lock 
    end
  end

  def after_load
    super

    @handled = false
  end

  def before_save
    # Update our timestamp
    if my = members[id]
      my['time'] = Time.now
    end
  end
  
  # Removes timed-out joins and parts.
  # Signs off on joins and parts.
  # Processes completed joins and parts.
  #
  # Should be called only once between load and save!
  def handle
    return if @handled

    # Remove completed/old joins
    joins.delete_if do |id, join|
      members.include? id or
      (Time.now - Time.parse(join['time'])) > JOIN_INTERVAL * 2
    end

    # Acknowledge joins in progress
    joins.each do |id, join|
      join['ack'] |= [self.id]
    end

    # Remove completed/old parts
    parts.delete_if do |id, part|
      (!members.include?(id) and part_acknowledged?(id)) or
      (Time.now - Time.parse(part['time'])) > PART_INTERVAL * 2
    end

    # Acknowledge parts in progress
    parts.each do |id, part|
      members.delete id
      part['ack'] |= [self.id]
    end

    @handled = true
  end

  def id
    #@id ||= "#{Socket.gethostname}:#{Process.pid}:#{Thread.current.__id__}:#{rand(10000)}"
    @id ||= rand(10000).to_s
  end

  # Joins the member pool.
  def join
    join_start
    save
    sleep JOIN_INTERVAL
    reload
    handle
    if join_acknowledged?
      join_complete
      save
      true
    else
      join_cancel
      save
      false
    end
  end

  # Check to see if we're approved to join.
  def join_acknowledged?(id = self.id)
    return false unless request = joins[id]

    (members.keys - request['ack']).empty?
  end

  # Cancel a join
  def join_cancel(id = self.id)
    joins.delete id
  end

  # Complete the join process
  def join_complete
    joins.delete id
    members[id] = {'time' => Time.now}
  end
  
  # Add ourselves to the join pool
  def join_start
    joins[id] = {
      'time' => Time.now,
      'ack' => [id]
    }
  end
  
  # Are members attempting to join?
  def joining?
    not joins.empty?
  end

  def lock
    @lock ||= Mutex.new
  end

  # Is the given ID a member?
  def member?(id)
    members.include? id
  end

  # Leave the pool 
  def part
    part_start
    save
    true
  end

  # Check if consensus reached on a part
  def part_acknowledged?(id = self.id)
    return false unless part = parts[id]

    (members.keys - parts.keys - part['ack']).empty?
  end

  # Complete the part
  def part_complete
    parts.delete id
  end

  # Begin removing a member
  def part_start(id = self.id)
    parts[id] = {
      'time' => Time.now,
      'ack' => [self.id]
    }
    members.delete id
  end

  # Are members leaving?
  def parting?
    not parts.empty?
  end

  # Save/reload the object in a mainloop of sorts.
  def main
    lock.synchronize do
      save
      reload
      handle
    end

    sleep RUN_INTERVAL
  end
  
  # Joins, runs main in a thread and yields, and leaves.
  def run
    join

    running = true
    t = Thread.new do
      while running
        main
      end
    end

    yield

    running = false
    t.join
  end

  # Is the member list stable?
  def stable?
    not (parting? or joining?)
  end

  def to_s
    id
  end
end
