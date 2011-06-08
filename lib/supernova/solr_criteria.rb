require "rsolr"

class Supernova::SolrCriteria < Supernova::Criteria
  DEFAULT_PER_PAGE = 25
  
  def to_params
    solr_options = { :fq => {}, :q => "*:*" }
    solr_options[:fq].merge!(self.filters[:with]) if self.filters[:with]
    solr_options[:sort] = self.search_options[:order] if self.search_options[:order]
    solr_options[:q] = self.filters[:search] if self.filters[:search]
    
    if self.search_options[:geo_center] && self.search_options[:geo_distance]
      solr_options[:pt] = "#{self.search_options[:geo_center][:lat]},#{self.search_options[:geo_center][:lng]}"
      solr_options[:d] = self.search_options[:geo_distance]
      solr_options[:sfield] = :location
      solr_options[:fq] = "{!geofilt}"
    end
    
    solr_options[:fq].merge!(:type => self.clazz.to_s) if self.clazz
    
    if self.search_options[:pagination]
      solr_options[:rows] = (self.search_options[:pagination][:per_page] || DEFAULT_PER_PAGE).to_i
      solr_options[:start] = ((self.search_options[:pagination][:page] || 1).to_i - 1) * solr_options[:rows]
    end
    solr_options
  end
  
  def to_a
    to_params
  end
end