module Risky::Timestamps
  # If created_at and/or updated_at are present, updates them before creation
  # and save, respectively.

  def before_save
    super
    begin
      self.updated_at = Time.now
    rescue
    end
  end

  def before_create
    super

    begin
      self.created_at ||= Time.now
    rescue
    end
  end
end
