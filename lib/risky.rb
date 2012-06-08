class Risky
  require 'set'
  require 'riak'
  require 'multi_json'

  $LOAD_PATH << File.expand_path(File.dirname(__FILE__))

  # Exceptions
  require 'risky/invalid'
  require 'risky/not_found'

  # Fix threading autoload bugs
  require 'risky/threadsafe'
  
  # Default plugins
  require 'risky/cron_list'
  require 'risky/indexes'
  require 'risky/timestamps'

  extend Enumerable

  # Get a model by key. Returns nil if not found. You can also pass opts to
  # #reload (e.g. :r, :merge => false).
  def self.[](key, opts = {})
    return nil unless key

    begin
      new(key).reload(opts)
    rescue Riak::FailedRequest => e
      raise e unless e.not_found?
      nil
    end
  end

  # Returns all model instances from the bucket. Why yes, this *could* be
  # expensive, Suzy!
  def self.all(opts = {:reload => true})
    bucket.keys(opts).map do |key|
      self[key]
    end
  end

  # Indicates that this model may be multivalued; in which case .merge should
  # also be defined.
  def self.allow_mult
    unless bucket.props['allow_mult']
      bucket.props = bucket.props.merge('allow_mult' => true)
    end
  end

  # The Riak::Bucket backing this model.
  # If name is passed, *sets* the bucket name.
  def self.bucket(name = nil)
    if name
      @bucket_name = name.to_s
    end
  
    riak.bucket(@bucket_name)
  end

  # The string name of the bucket used for storing instances of this model.
  def self.bucket_name
    @bucket_name
  end

  def self.bucket_name=(bucket)
    @bucket_name = name.to_s
  end

  # Casts data to appropriate types for values.
  def self.cast(data)
    casted = {}
    data.each do |k, v|
      c = @values[k][:class] rescue nil
      casted[k] = begin
        if c == Time
          Time.iso8601(v)
        else
          v
        end
      rescue
        v
      end
    end
    casted
  end

  # Counts the number of values in the bucket via key streaming
  def self.count
    count = 0
    bucket.keys do |keys|
      count += keys.length
    end
    count
  end

  # Returns true when record deleted.
  # Returns nil when record was not present to begin with.
  def self.delete(key, opts = {})
    return if key.nil?
    (bucket.delete(key.to_s, opts)[:code] == 204) or nil
  end

  # Iterate over all items using key streaming.
  def self.each
    bucket.keys do |keys|
      keys.each do |key|
        if x = self[key]
          yield x
        end
      end
    end
  end

  # Does the given key exist in our bucket?
  def self.exists?(key)
    return if key.nil?
    bucket.exists? key.to_s
  end

  # Fills in values from a Riak::RObject
  def self.from_riak_object(riak_object)
    return nil if riak_object.nil?

    n = new.load_riak_object riak_object

    # Callback
    n.after_load
    n
  end

  # Gets an existing record or creates one.
  def self.get_or_new(*args)
    self[*args] or new(args.first)
  end
  
  # Iterate over all keys.
  def self.keys(*a)
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

  # Establishes methods for manipulating a single link with a given tag.
  def self.link(tag)
    tag = tag.to_s
    class_eval "
      def #{tag}
        begin
          @riak_object.links.find do |l|
            l.tag == #{tag.inspect}
          end.key
        rescue NoMethodError
          nil
        end
      end

      def #{tag}=(link)
        @riak_object.links.reject! do |l|
          l.tag == #{tag.inspect}
        end
        if link
          @riak_object.links << link.to_link(#{tag.inspect})
        end
      end
    "
  end

  # Establishes methods for manipulating a set of links with a given tag.
  def self.links(tag)
    tag = tag.to_s
    class_eval "
      def #{tag}
        @riak_object.links.select do |l|
          l.tag == #{tag.inspect}
        end.map do |l|
          l.key
        end
      end

      def add_#{tag}(link)
        @riak_object.links << link.to_link(#{tag.inspect})
      end

      def remove_#{tag}(link)
        @riak_object.links.delete link.to_link(#{tag.inspect})
      end

      def clear_#{tag}
        @riak_object.links.delete_if do |l|
          l.tag == #{tag.inspect}
        end
      end
      
      def #{tag}_count
        @riak_object.links.select{|l| l.tag == #{tag.inspect}}.length
      end
    "
  end

  # Mapreduce helper
  def self.map(*args)
    mr.map(*args)
  end

  # Merges n versions of a record together, for read-repair.
  # Returns the merged record.
  def self.merge(versions)
    versions.first
  end

  # Begins a mapreduce on this model's bucket.
  # If no keys are given, operates on the entire bucket.
  # If keys are given, operates on those keys first.
  def self.mr(keys = nil)
    mr = Riak::MapReduce.new(riak)

    if keys
      # Add specific keys
      [*keys].compact.inject(mr) do |mr, key|
        mr.add @bucket_name, key.to_s
      end
    else
      # Add whole bucket
      mr.add @bucket_name
    end
  end

  # MR helper.
  def self.reduce(*args)
    mr.reduce(*args)
  end

  # The Riak::Client backing this model class.
  def self.riak
    if @riak_client
      @riak_client
    elsif @riak and @riak.respond_to? :call
      @riak_client = @riak.call(self)
    elsif @riak
      @riak_client = @riak
    else
      superclass.riak
    end
  end

  # Forces this model's Riak client to be reset.
  # If your @riak proc can choose between multiple hosts, calling this on
  # failure will allow subsequent requests to proceed on another host.
  def self.riak!
    @riak_client = nil
    riak
  end

  # Sets the Riak Client backing this model class. If client is a lambda (or
  # anything responding to #call), it will be invoked to generate a new client
  # every time Risky feels it is appropriate.
  def self.riak=(client)
    @riak = client
  end
 
  # Add a new value to this model. Values aren't necessary; you can 
  # use Risky#[], but if you would like to cast values to/from JSON or
  # specify defaults, you may: 
  # 
  # :default => object (#clone is called for each new instance)
  # :class => Time, Integer, etc. Inferred from default.class if present.
  def self.value(value, opts = {})
    value = value.to_s

    klass = if opts[:class]
      opts[:class]
    elsif opts.include? :default
      opts[:default].class
    else
      nil
    end
    values[value] = opts.merge(:class => klass)
    
    class_eval "
      def #{value}; @values[#{value.inspect}]; end
      def #{value}=(value); @values[#{value.inspect}] = value; end
    "
  end

  # A list of all values we track.
  def self.values
    @values ||= {}
  end



  attr_accessor :values
  attr_accessor :riak_object

  # Create a new instance from a key and a list of values.
  #
  # Values will be passed to attr= methods where possible, so you can write
  # def password=(p)
  #   self['password'] = md5sum p
  # end
  # User.new('me', :password => 'baggins')
  def initialize(key = nil, values = {})
    super()

    key = key.to_s unless key.nil?

    @riak_object ||= Riak::RObject.new(self.class.bucket, key)
    @riak_object.content_type = 'application/json'

    @new = true
    @merged = false
    @values = {}

    # Load values
    values.each do |k,v|
      begin
        send(k.to_s + '=', v)
      rescue NoMethodError
        self[k] = v
      end
    end

    # Fill in defults.
    self.class.values.each do |k,v|
      if self[k].nil?
        self[k] = (v[:default].clone rescue v[:default])
      end
    end 
  end

  # Two models compare === if they are of matching class and key.
  def ===(o)
    o.class == self.class and o.key.to_s == self.key.to_s rescue false
  end

  # Access the values hash.
  def [](k)
    @values[k]
  end

  # Access the values hash.
  def []=(k, v)
    @values[k] = v
  end

  def after_create
  end

  def after_delete
  end

  # Called when a riak object is used to populate the instance.
  def after_load
  end

  def after_save
  end

  def as_json(opts = {})
    h = @values.merge(:key => key)
    h[:errors] = errors unless errors.empty?
    h 
  end

  # Called before creation and validation
  def before_create
  end

  # Called before deletion
  def before_delete
  end

  # Called before saving and before validation
  def before_save
  end

  # Delete this object in the DB and return self.
  def delete
    before_delete
    @riak_object.delete
    after_delete

    self
  end

  # A hash for errors on this object
  def errors
    @errors ||= {}
  end

  # Replaces values and riak_object with data from riak_object.
  def load_riak_object(riak_object, opts = {:merge => true})
    if opts[:merge] and riak_object.conflict? and siblings = riak_object.siblings
      # Engage conflict resolution mode
      final = self.class.merge(
        siblings.map do |sibling|
          self.class.new.load_riak_object(sibling, :merge => false)
        end
      )

      # Copy final values to self.
      final.instance_variables.each do |var|
        self.instance_variable_set(var, final.instance_variable_get(var))
      end

      self.merged = true
    else
      # Not merging
      self.values = self.class.cast(MultiJson.load(riak_object.raw_data)) rescue {}
      self.class.values.each do |k, v|
        if values[k].nil?
          values[k] = (v[:default].clone rescue v[:default])
        end
      end
      self.riak_object = riak_object
      self.new = false
      self.merged = false
    end
    
    self
  end

  def inspect
    "#<#{self.class} #{key} #{@values.inspect}>"
  end

  def key=(key)
    if key.nil?
      @riak_object.key = nil
    else
      @riak_object.key = key.to_s
    end 
  end

  def key
    @riak_object.key
  end

  def merged=(merged)
    @merged = !!merged
  end

  # Has this model been merged from multiple siblings?
  def merged?
    @merged
  end

  def new=(new)
    @new = !!new
  end

  # Is this model freshly created; i.e. not saved in the database yet?
  def new?
    @new
  end

  # Reload this model's data from Riak.
  # opts are passed to Riak::Bucket[]
  def reload(opts = {})
    # Get object from riak.
    riak_object = self.class.bucket[key, opts]

    # Load
    load_riak_object riak_object

    # Callback
    after_load
    self
  end

  # Saves this model.
  # 
  # Calls #validate and #valid? unless :validate is false.
  #
  # Converts @values to_json and saves it to riak.
  #
  # :w and :dw are also supported.
  def save(opts = {})
    before_create if @new
    before_save

    unless opts[:validate] == false
      return false unless valid?
    end

    @riak_object.raw_data = MultiJson.dump @values
	  @riak_object.content_type = "application/json"
    
    store_opts = {}
    store_opts[:w] = opts[:w] if opts[:w]
    store_opts[:dw] = opts[:dw] if opts[:dw]
    @riak_object.store store_opts

    after_create if @new
    after_save

    @new = false

    self
  end

  # This is provided for convenience; #save does *not* use this method, and you
  # are free to override it.
  def to_json(*a)
    as_json.to_json(*a)
  end

  # Returns a Riak::Link object pointing to this record.
  def to_link(*a)
    @riak_object.to_link(*a)
  end

  # Calls #validate and checks whether the errors hash is empty.
  def valid?
    @errors = {}
    validate
    @errors.empty?
  end  
 
  # Determines whether the model is valid. Sets the contents of #errors if
  # invalid. 
  def validate
    if key.blank?
      errors[:key] = 'is missing'
    end
  end
end
