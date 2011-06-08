require "supernova/solr_criteria"

module Supernova::Solr
  class << self
    attr_accessor :url
    
    def connection
      @connection ||= RSolr.connect(:url => self.url)
    end
    
    def truncate!
      connection.delete_by_query("*:*")
    end
  end
  
  def self.included(base)
    base.extend(Supernova::ClassMethods)
    base.criteria_class = Supernova::SolrCriteria
  end
end