require "search_scope/thinking_sphinx_criteria"

module SearchScope::ThinkingSphinx
  def self.included(base)
    base.extend(SearchScope::ClassMethods)
    base.criteria_class = SearchScope::ThinkingSphinxCriteria
  end
end