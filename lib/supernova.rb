require "rsolr"
require "active_support/core_ext/object/blank"
require "active_support/core_ext/hash"

module Supernova
  KM_TO_METER = 1000.0
  MILE_TO_METER = 1609.3472
  DEG_TO_RADIAN = Math::PI / 180.0
  RADIAN_TO_REG = 1 / DEG_TO_RADIAN
  
  module ClassMethods
    attr_accessor :criteria_class, :defined_named_search_scopes
    
    def search_scope
      self.criteria_class.new(self).named_scope_class(self)
    end
    
    def named_search_scope(name, &block)
      self.class.send(:define_method, name) do |*args|
        self.search_scope.instance_exec(*args, &block)
      end
      self.defined_named_search_scopes ||= []
      self.defined_named_search_scopes << name
    end
  end
  
  class << self
    def build_ar_like_record(clazz, attributes, original_search_doc = nil)
      record = clazz.new
      record.instance_variable_set("@attributes", attributes)
      record.instance_variable_set("@readonly", true)
      record.instance_variable_set("@new_record", false)
      record.instance_variable_set("@original_search_doc", original_search_doc) if original_search_doc
      record
    end
  end
end

require "supernova/numeric_extensions"
require "supernova/symbol_extensions"
require "supernova/condition"
require "supernova/collection"
require "supernova/criteria"
require "supernova/thinking_sphinx"
require "supernova/solr"