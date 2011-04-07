class Risky::NotFound < RuntimeError
  attr_accessor :key

  def initialize(key, message = nil)
    @record = key
    @message = message || "record not found"
  end

  def to_s
    @message
  end
end
