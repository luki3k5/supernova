Numeric.class_eval do
  KM_TO_METER = 1000.0
  MILE_TO_METER = 1609.3472
  DEG_TO_RADIAN = Math::PI / 180.0
  RADIAN_TO_REG = 1 / DEG_TO_RADIAN
  
  def km
    self * KM_TO_METER
  end
  
  def meter
    self.to_f
  end
  
  def mile
    self * MILE_TO_METER
  end
  
  def to_radians
    self * DEG_TO_RADIAN
  end
  
  def to_deg
    self * RADIAN_TO_REG
  end
  
  alias_method :miles, :mile
  alias_method :kms, :km
  alias_method :meters, :meter
end