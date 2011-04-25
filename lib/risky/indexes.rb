module Risky::Indexes
  # Provides indexes on an attribute. Mostly.

  def self.included(base)
    base.instance_eval do
      @indexes = {}
     
      def indexes
        @indexes
      end

      # Options:
      # :proc => Anything responding to #[record]. Returns the key used for the index.
      # :unique => Perform a unique check to ensure this index does not
      #            conflict with another record.
      def index(attribute, opts = {})
        opts[:bucket] ||= "#{@bucket_name}_by_#{attribute}"
        @indexes[attribute] = opts
        
        class_eval %{
          def self.by_#{attribute}(value)
            return nil unless value

            begin
              from_riak_object(
                Riak::RObject.new(
                  riak[#{opts[:bucket].inspect}],
                  value.to_s
                ).walk(:bucket => #{@bucket_name.inspect}).first.first
              )
            rescue Riak::FailedRequest => e
              raise e unless e.code.to_i == 404
              nil
            end
          end
        }
      end
    end
  end

  def initialize(*a)
    @old_indexed_values = {}
    
    super *a
  end

  def after_load
    super

    self.class.indexes.each do |attr, opts|
      @old_indexed_values[attr] = opts[:proc][self] rescue self[attr.to_s]
    end
  end

  def after_save
    super

    self.class.indexes.each do |attr, opts|
      current = opts[:proc][self] rescue self[attr.to_s]
      old = @old_indexed_values[attr]
      @old_indexed_values[attr] = current

      unless old == current
        # Remove old index
        if old
          self.class.riak[opts[:bucket]].delete(old) rescue nil
        end

        # Create new index
        unless current.nil?
          index = Riak::RObject.new(self.class.riak[opts[:bucket]], current.to_s)
          index.content_type = 'text/plain'
          index.data = ''
          index.links = Set.new([@riak_object.to_link('value')])
          index.store
        end
      end
    end
  end

  def before_delete
    super

    self.class.indexes.each do |attr, opts|
      if key = @old_indexed_values[attr]
        self.class.riak[opts[:bucket]].delete(key) rescue nil
      end
    end
  end

  def validate
    super

    # Validate unique indexes
    self.class.indexes.each do |attr, opts|
      next unless opts[:unique]
      
      current = opts[:proc][self] rescue self[attr.to_s]
      old = @old_indexed_values[attr]

      next if current.nil?
      next if current == old

      # Validate that the record belongs to us.
      begin
        existing = self.class.riak[opts[:bucket]][current]
        existing_key = existing.links.find { |l| l.tag == 'value' }.key
      rescue
        # Any failure here means no current index exists exists.
        next
      end

      if existing_key and (new? or key != existing_key)
        # Conflicts!
        errors[attr.to_sym] = 'taken'
      end
    end
  end
end
