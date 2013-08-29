module Risky::ListKeys

  def self.included(base)
    base.extend ClassMethods
  end

  module ClassMethods
    # Returns all model instances from the bucket
    def all(opts = {:reload => true})
      find_all_by_key(bucket.keys(opts))
    end

    # Counts the number of values in the bucket via key streaming.
    def count
      count = 0
      bucket.keys do |keys|
        count += keys.length
      end
      count
    end

    # Deletes all model instances from the bucket.
    def delete_all
      each do |item|
        item.delete
      end
    end

    # Iterate over all keys.
    def keys(*a)
      if block_given?
        bucket.keys(*a) do |keys|
          # This API is currently inconsistent from protobuffs to http
          if keys.kind_of? Array
            keys.each do |key|
              yield key
            end
          else
            yield keys
          end
        end
      else
        bucket.keys(*a)
      end
    end

    # Iterate over all items using key streaming.
    def each
      bucket.keys do |keys|
        keys.each do |key|
          if x = self[key]
            yield x
          end
        end
      end
    end
  end
end
