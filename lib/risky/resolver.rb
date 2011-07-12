module Risky::Resolver
  # Makes it easy to resolve conflicts in an object in different ways.
  #
  # class User
  #   include Risky::Resolver
  #   value :union, :resolve => :union
  #   value :union, :resolve => lambda do |xs| xs.first end
 
  module ClassMethods
    def merge(versions)
      p = super(versions).clone
     
      # For each field, use the given resolver to merge all the conflicting
      # values together.
      values.each do |value, opts|
        next unless resolver = opts[:resolve]

        # Convert symbols and such to callables.
        unless resolver.respond_to? :call
          resolver = begin
            # Try our resolvers
            Resolvers.method resolver
          rescue
            # Try a class method
            method resolver
          end
        end

        # Resolve and set
        p.send("#{value}=", resolver.call(
          versions.map do |version|
            version.send value
          end
        ))
      end

      p
    end
  end

  module Resolvers
    extend self

    def intersection(xs)
      xs.compact.inject do |i, x|
        i & x
      end
    end
    
    def max(xs)
      xs.compact.max
    end

    def merge(xs)
      xs.compact.inject do |m, x|
        m.merge x
      end
    end

    def min(xs)
      xs.compact.min
    end

    def union(xs)
      xs.compact.inject do |u, x|
        u | x
      end
    end
  end

  def self.included(base)
    base.extend ClassMethods
  end
end
