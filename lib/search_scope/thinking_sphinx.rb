require "search_scope/sphinx_criteria"

module SearchScope::ThinkingSphinx
  def self.included(base)
    base.extend(SearchScope::ClassMethods)
    base.criteria_class = SearchScope::SphinxCriteria
  end
end