module SearchScope
  module ClassMethods
    attr_accessor :criteria_class
    
    def search_scope(name, &block)
      self.class.send(:define_method, name) do
        self.criteria_class.new(self).instance_eval(&block)
      end
    end
  end
end

require "search_scope/criteria"
require "search_scope/thinking_sphinx"