require "supernova/thinking_sphinx_criteria"

module Supernova::ThinkingSphinx
  def self.included(base)
    base.extend(Supernova::ClassMethods)
    base.criteria_class = Supernova::ThinkingSphinxCriteria
  end
end