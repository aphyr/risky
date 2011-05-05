module Risky::Queue
  # This module, when included, allows a model to act as a queue of items for
  # multiple readers. It guarantees:
  #
  # 1. No items will be lost.
  # 2. Items will be processed in roughly sequential order.
  # 
  # Adding an item is instantaneous. Removing an item requires lock_time
  # seconds. An item may be processed multiple times in the event that state
  # replication does not succeed within lock_time.

  DEFAULT_LOCK_TIME = 4

  def self.included?(base)
    base.instance_eval do

      allow_mult

      value :free => {}
      value :locked => Hash.new { {} }

      attr_accessor :id

      # How long to wait before a lock is acquired. Shorter times mean lower
      # latency, but also more frequent polling.
      def lock_time(time = nil)
        if time
          @lock_time = time
        else
          @lock_time
        end
      end

      def self.merge(versions)

      end

    end
  end

  def initialize(id)
    @id = id || `#{hostname}:#{Process.pid}:#{Thread.id}:`
  end

  # Begins to acquire a lock on key
  def lock_start(key)
    locked[id]= free.delete(key)
  end

  # Finalizes acquires in progress
  def lock_finish(key)

  end
end
