class Supernova::Criteria
  DEFAULT_PER_PAGE = 25
  FIRST_PAGE = 1
  
  attr_accessor :filters, :search_options, :clazz

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
    self.search_options = {}
  end

  def for_classes(clazzes)
    merge_filters :classes, [clazzes].flatten
  end
  
  def attribute_mapping(mapping)
    merge_search_options :attribute_mapping, mapping
  end

  def order(order_option)
    merge_search_options :order, order_option
  end

  def limit(limit_option)
    merge_search_options :limit, limit_option
  end

  def group_by(group_option)
    merge_search_options :group_by, group_option
  end

  def search(*terms)
    merge_filters_array :search, terms
  end

  def with(filters)
    merge_filters :with, filters
  end
  
  def where(*args)
    with(*args)
  end
  
  def without(filters)
    self.filters[:without] ||= Hash.new
    filters.each do |key, value|
      self.filters[:without][key] ||= Array.new
      self.filters[:without][key] << value if !self.filters[:without][key].include?(value)
    end
    self
  end

  def select(*fields)
    merge_filters_array :select, fields
  end

  def conditions(filters)
    merge_filters :conditions, filters
  end

  def paginate(pagination_options)
    merge_search_options :pagination, pagination_options
  end
  
  def near(*coordinates)
    merge_search_options :geo_center, normalize_coordinates(*coordinates)
  end
  
  def within(distance)
    merge_search_options :geo_distance, distance
  end
  
  def options(options_hash)
    merge_search_options :custom_options, options_hash
  end
  
  def normalize_coordinates(*args)
    flattened = args.flatten
    if (lat = read_first_attribute(flattened.first, :lat, :latitude)) && (lng = read_first_attribute(flattened.first, :lng, :lon, :longitude))
      { :lat => lat.to_f, :lng => lng.to_f }
    elsif flattened.length == 2
      { :lat => flattened.first.to_f, :lng => flattened.at(1).to_f }
    end
  end
  
  def read_first_attribute(object, *keys)
    keys.each do |key|
      return object.send(key) if object.respond_to?(key)
    end
    nil
  end

  def merge_filters(key, value)
    merge_filters_or_search_options(self.filters, key, value)
  end
  
  def merge_filters_array(key, fields)
    self.search_options[key] ||= Array.new
    fields.flatten.each do |field|
      self.search_options[key] << field if !self.search_options[key].include?(field)
    end
    self
  end

  def merge_search_options(key, value)
    merge_filters_or_search_options(self.search_options, key, value)
  end

  def merge_filters_or_search_options(reference, key, value)
    if value.is_a?(Hash)
      reference[key] ||= Hash.new
      reference[key].merge!(value)
    elsif key == :select
      reference[key] ||= Array.new
      reference[key] += (value || [])
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
  
  def current_page
    pagination_attribute_when_greater_zero(:page) || 1
  end
  
  def per_page
    pagination_attribute_when_greater_zero(:per_page) || DEFAULT_PER_PAGE
  end
  
  def pagination_attribute_when_greater_zero(attribute)
    self.search_options[:pagination][attribute] if self.search_options[:pagination] && self.search_options[:pagination][attribute].to_i > 0
  end

  def implement_in_subclass
    raise "implement in subclass"
  end
  
  def merge(other_criteria)
    other_criteria.filters.each do |key, value|
      self.merge_filters(key, value)
    end
    other_criteria.search_options.each do |key, value|
      self.merge_search_options(key, value)
    end
    self
  end

  def method_missing(*args, &block)
    if args.length == 1 && Array.new.respond_to?(args.first)
      to_a.send(args.first, &block)
    elsif self.named_scope_defined?(args.first)
      self.merge(self.search_options[:named_scope_class].send(*args)) # merge named scope and current criteria
    else
      super
    end
  end
  
  def named_scope_class(clazz)
    merge_search_options :named_scope_class, clazz
  end
  
  def named_scope_defined?(name)
    self.search_options[:named_scope_class] && self.search_options[:named_scope_class].respond_to?(:defined_named_search_scopes) && self.search_options[:named_scope_class].defined_named_search_scopes.respond_to?(:include?) && self.search_options[:named_scope_class].defined_named_search_scopes.include?(name)
  end
end