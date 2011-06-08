require "thinking_sphinx"

class Supernova::ThinkingSphinxCriteria < Supernova::Criteria
  def self.index_statement_for(field_name, column = nil)
    column ||= field_name
    [%(CONCAT("#{field_name}_", #{column})), { :as => :"indexed_#{field_name}" }]
  end
  
  def to_params
    sphinx_options = { :match_mode => :boolean, :with => {}, :conditions => {} }
    sphinx_options[:order] = self.options[:order] if self.options[:order]
    sphinx_options[:limit] = self.options[:limit] if self.options[:limit]
    sphinx_options[:select] = self.options[:select] if self.options[:select]
    sphinx_options[:group_by] = self.options[:group_by] if self.options[:group_by]
    sphinx_options.merge!(self.options[:pagination]) if self.options[:pagination].is_a?(Hash)
    sphinx_options[:classes] = self.filters[:classes] if self.filters[:classes]
    sphinx_options[:conditions].merge!(self.filters[:conditions]) if self.filters[:conditions]
    sphinx_options[:with].merge!(self.filters[:with]) if self.filters[:with]
    
    if self.options[:geo_center] && self.options[:geo_distance]
      sphinx_options[:geo] = [self.options[:geo_center][:lat].to_radians, self.options[:geo_center][:lng].to_radians]
      sphinx_options[:with]["@geodist"] = self.options[:geo_distance]
    end
    [self.filters[:search], sphinx_options]
  end
  
  def to_a
    ThinkingSphinx.search(*self.to_params)
  end
  
  def ids
    ThinkingSphinx.search_for_ids(*self.to_params)
  end
  
  def total_entries
    ids.total_entries
  end
end