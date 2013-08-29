class Risky::PaginatedCollection < Array

  attr_reader :keys, :continuation

  def initialize(collection, paginated_keys)
    @keys = paginated_keys
    @continuation = paginated_keys.continuation

    super(collection)
  end
end
