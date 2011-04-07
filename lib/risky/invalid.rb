class Risky::Invalid < RuntimeError
  attr_accessor :record

  def initialize(record, message = nil)
    @record = record
    @message = message || "record invalid"
  end

  def errors
    @record.errors
  end

  def to_s
    @message
  end
end
