Numeric.class_eval do
  def km
    self * Supernova::KM_TO_METER
  end
  
  def meter
    self.to_f
  end
  
  def mile
    self * Supernova::MILE_TO_METER
  end
  
  def to_radians
    self * Supernova::DEG_TO_RADIAN
  end
  
  def to_deg
    self * Supernova::RADIAN_TO_REG
  end
  
  alias_method :miles, :mile
  alias_method :kms, :km
  alias_method :meters, :meter
end