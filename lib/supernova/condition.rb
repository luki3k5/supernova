class Supernova::Condition
  attr_accessor :key, :type
  
  def initialize(key, type)
    self.key = key
    self.type = type
  end
  
  def solr_filter_for(value)
    case type
      when :not, :ne
        if value.nil?
          "#{self.key}:[* TO *]"
        else
          "!#{self.key}:#{value}"
        end
      when :gt
        "#{self.key}:{#{value} TO *}"
      when :gte
        "#{self.key}:[#{value} TO *]"
      when :lt
        "#{self.key}:{* TO #{value}}"
      when :lte
        "#{self.key}:[* TO #{value}]"
      when :nin
        "!(#{or_key_and_value(key, value)})"
      when :in
        or_key_and_value(key, value)
    end
  end
  
  def or_key_and_value(key, values)
    values.map { |v| "#{key}:#{v}"}.join(" OR ")
  end
end