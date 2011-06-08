class Supernova::Criteria
  attr_accessor :filters, :options, :clazz

  class << self
    def method_missing(*args)
      scope = self.new
      if scope.respond_to?(args.first)
        scope.send(*args)
      else
        super
      end
    end
  
    def select(*args)
      self.new.send(:select, *args)
    end
  end

  def initialize(clazz = nil)
    self.clazz = clazz
    self.filters = {}
    self.options = {}
  end

  def for_classes(clazzes)
    merge_filters :classes, [clazzes].flatten
  end

  def order(order_option)
    merge_options :order, order_option
  end

  def limit(limit_option)
    merge_options :limit, limit_option
  end

  def group_by(group_option)
    merge_options :group_by, group_option
  end

  def search(query)
    merge_filters :search, query
  end

  def with(filters)
    merge_filters :with, filters
  end

  def select(fields)
    merge_options :select, fields
  end

  def conditions(filters)
    merge_filters :conditions, filters
  end

  def paginate(options)
    merge_options :pagination, options
  end

  def merge_filters(key, value)
    merge_filters_or_options(self.filters, key, value)
  end

  def merge_options(key, value)
    merge_filters_or_options(self.options, key, value)
  end

  def merge_filters_or_options(reference, key, value)
    if value.is_a?(Hash)
      reference[key] ||= Hash.new
      reference[key].merge!(value)
    else
      reference[key] = value
    end
    self
  end

  def to_parameters
    implement_in_subclass
  end

  def to_a
    implement_in_subclass
  end

  def implement_in_subclass
    raise "implement in subclass"
  end
  
  def merge(other_criteria)
    other_criteria.filters.each do |key, value|
      self.merge_filters(key, value)
    end
    other_criteria.options.each do |key, value|
      self.merge_options(key, value)
    end
    self
  end

  def method_missing(*args, &block)
    if args.length == 1 && Array.new.respond_to?(args.first)
      to_a.send(args.first, &block)
    elsif self.named_scope_defined?(args.first)
      self.merge(self.clazz.send(*args)) # merge named scope and current criteria
    else
      super
    end
  end
  
  def named_scope_defined?(name)
    self.clazz && self.clazz.respond_to?(:defined_named_search_scopes) && clazz.defined_named_search_scopes.respond_to?(:include?) && clazz.defined_named_search_scopes.include?(name)
  end
end