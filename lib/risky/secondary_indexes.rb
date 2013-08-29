require 'risky/inflector'
require 'risky/paginated_collection'

module Risky::SecondaryIndexes

  def self.included(base)
    base.extend ClassMethods
  end

  module ClassMethods
    # Add a new secondary index to this model.
    # Default option is :type => :int, can also be :bin
    # Default option is :multi => false, can also be true
    # Option :map can be used to map the index to a model (see map_model).
    #   This assumes by default that the index name ends in _id (use :map => true)
    #   If it ends in something else, use :map => '_suffix'
    def index2i(name, opts = {})
      name = name.to_s

      opts.replace({:type => :int, :multi => false, :finder => :find}.merge(opts))
      indexes2i[name] = opts

      class_eval %Q{
        def #{name}
          @indexes2i['#{name}']
        end

        def #{name}=(value)
          @indexes2i['#{name}'] = value
        end
      }

      if opts[:map]
        if opts[:map] === true # assume that it ends in _id
          model_name = name[0..-4]
          map_model(model_name, opts)
        else
          model_name = name[0..-(opts[:map].length + 1)]
          map_model(model_name, opts.merge(:suffix => opts[:map]))
        end
      end
    end

    # A list of all secondary indexes
    def indexes2i
      @indexes2i ||= {}
    end

    def find_by_index(index2i, value)
      index = "#{index2i}_#{indexes2i[index2i.to_s][:type]}"
      key = bucket.get_index(index, value).first
      return nil if key.nil?

      find(key)
    end

    def find_all_by_index(index2i, value)
      index = "#{index2i}_#{indexes2i[index2i.to_s][:type]}"
      keys = bucket.get_index(index, value)

      find_all_by_key(keys)
    end

    def find_all_keys_by_index(index2i, value)
      index = "#{index2i}_#{indexes2i[index2i.to_s][:type]}"
      bucket.get_index(index, value)
    end

    def paginate_by_index(index2i, value, opts = {})
      keys = paginate_keys_by_index(index2i, value, opts)
      Risky::PaginatedCollection.new(find_all_by_key(keys), keys)
    end

    def paginate_keys_by_index(index2i, value, opts = {})
      index = "#{index2i}_#{indexes2i[index2i.to_s][:type]}"
      bucket.get_index(index, value, opts)
    end

    def create(key, values = {}, indexes2i = {}, opts = {})
      obj = new key, values, indexes2i
      obj.save(opts)
    end

    # The map_model method is a convenience method to map the model_id to getters and setters.
    # The assumption is that you have a value or index2i for model_id.
    # The default suffix is '_id', so map_model :promotion implies that promotion_id is the index2i.
    #
    # For example, map_model :promotion will create these three methods
    # ```ruby
    # def promotion
    #   @promotion ||= Promotion.find_by_id promotion_id
    # end
    #
    # def promotion=(value)
    #   @promotion = promotion
    #   self.promotion_id = value.nil? ? nil : value.id
    # end
    #
    # def promotion_id=(value)
    #   @promotion = nil if self.promotion_id != value
    #   indexes2i['promotion_id'] = value
    # end
    # ```
    def map_model(model_name, opts = {})
      model_name = model_name.to_s
      class_name = Risky::Inflector.classify(model_name)

      opts.replace({:type => :index2i, :suffix => '_id'}.merge(opts))

      class_eval %Q{
        def #{model_name}
          @#{model_name} ||= #{class_name}.#{opts[:finder]} #{model_name}#{opts[:suffix]}
        end

        def #{model_name}=(value)
          @#{model_name} = value
          self.#{model_name}#{opts[:suffix]} = value.nil? ? nil : value.id
        end

        def #{model_name}_id=(value)
          @#{model_name} = nil if self.#{model_name}_id != value
          indexes2i['#{model_name}#{opts[:suffix]}'] = value
        end
      }
    end
  end


  ### Instance methods
  def initialize(key = nil, values = {}, indexes2i = {})
    super((key.nil? ? nil : key.to_s), values)

    # Parse anything not parsed correctly by Yajl (no support for json_create)
    self.class.values.each do |k,v|
      if self[k].is_a?(Hash) && self[k]['json_class']
        klass = Risky::Inflector.constantize(self[k]['json_class'])
        self[k] = klass.send(:json_create, self[k])
      end
    end

    @indexes2i = {}

    indexes2i.each do |k,v|
      send(k.to_s + '=', v)
    end
  end

  def save(opts = {})
    self.class.indexes2i.each do |k, v|
      raise ArgumentError, "Nil for index #{k} on #{self.class.name}" if (v[:multi] ? @indexes2i[k].nil? : @indexes2i[k].blank?) && !v[:allow_nil]

      case v[:type]
      when :int
        @riak_object.indexes["#{k}_int"] = v[:multi] && @indexes2i[k].respond_to?(:map) ? @indexes2i[k].map(&:to_i) : [ @indexes2i[k].to_i ]
      when :bin
        @riak_object.indexes["#{k}_bin"] = v[:multi] && @indexes2i[k].respond_to?(:map) ? @indexes2i[k].map(&:to_s) : [ @indexes2i[k].to_s ]
      else
        raise TypeError, "Invalid 2i type '#{v[:type]}' for index #{k} on #{self.class.name}"
      end
    end

    super(opts)
  end

  def load_riak_object(riak_object, opts = {:merge => true})
    super(riak_object, opts)

    # Parse anything not parsed correctly by Yajl (no support for json_create)
    self.class.values.each do |k,v|
      if self[k].is_a?(Hash) && self[k]['json_class']
        klass = Risky::Inflector.constantize(self[k]['json_class'])
        self[k] = klass.send(:json_create, self[k])
      end
    end

    self.class.indexes2i.each do |k, v|
      case v[:type]
      when :int
        @indexes2i[k] = v[:multi] ? @riak_object.indexes["#{k}_int"].map(&:to_i) : @riak_object.indexes["#{k}_int"].first.to_i
      when :bin
        @indexes2i[k] = v[:multi] ? @riak_object.indexes["#{k}_bin"].map(&:to_s) : @riak_object.indexes["#{k}_bin"].first.to_s
      else
        raise TypeError, "Invalid 2i type '#{v[:type]}' for index #{k} on #{self.class.name}"
      end
    end

    self
  end

  def indexes2i
    @indexes2i
  end

  def inspect
    "#<#{self.class} #{key} #{@indexes2i.inspect} #{@values.inspect}>"
  end
end
