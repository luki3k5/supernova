require "thinking_sphinx"
require "zlib"

class Supernova::ThinkingSphinxCriteria < Supernova::Criteria
  def self.index_statement_for(field_name, column = nil)
    column ||= field_name
    [%(CONCAT("#{field_name}_", #{column})), { :as => :"indexed_#{field_name}" }]
  end
  
  def normalize_with_filter(attributes)
    attributes.inject({}) do |hash, (key, value)|
      value = Zlib.crc32(value.to_s) if value.is_a?(String) || value.is_a?(Class)
      hash.merge!(key => value)
    end
  end
  
  def to_params
    sphinx_options = { :match_mode => :boolean, :with => {}, :conditions => {}, :without => {} }
    sphinx_options[:order] = self.search_options[:order] if self.search_options[:order]
    sphinx_options[:limit] = self.search_options[:limit] if self.search_options[:limit]
    sphinx_options[:select] = self.search_options[:select] if self.search_options[:select]
    sphinx_options[:group_by] = self.search_options[:group_by] if self.search_options[:group_by]
    sphinx_options.merge!(self.search_options[:pagination]) if self.search_options[:pagination].is_a?(Hash)
    sphinx_options[:classes] = self.filters[:classes] if self.filters[:classes]
    sphinx_options[:classes] = [self.clazz] if self.clazz
    sphinx_options[:conditions].merge!(self.filters[:conditions]) if self.filters[:conditions]
    sphinx_options[:with].merge!(normalize_with_filter(self.filters[:with])) if self.filters[:with]
    sphinx_options[:without].merge!(normalize_with_filter(self.filters[:without])) if self.filters[:without]
    sphinx_options.merge!(self.search_options[:custom_options]) if self.search_options[:custom_options]
    if self.search_options[:geo_center] && self.search_options[:geo_distance]
      sphinx_options[:geo] = [self.search_options[:geo_center][:lat].to_radians, self.search_options[:geo_center][:lng].to_radians]
      sphinx_options[:with]["@geodist"] = self.search_options[:geo_distance].is_a?(Range) ? self.search_options[:geo_distance] : Range.new(0.0, self.search_options[:geo_distance])
    end
    [(self.search_options[:search] || Array.new).join(" "), sphinx_options]
  end
  
  def to_a
    ThinkingSphinx.search(*self.to_params)
  end
  
  def ids
    params = *self.to_params
    ThinkingSphinx.search_for_ids(*params)
  end
  
  def total_entries
    ids.total_entries
  end
end