require "rsolr"

class Supernova::SolrCriteria < Supernova::Criteria
  # move this into separate methods (test each separatly)
  def to_params
    solr_options = { :fq => [], :q => "*:*" }
    solr_options[:fq] += fq_from_with(self.filters[:with])
    if self.filters[:without]
     self.filters[:without].each do |field, values| 
       solr_options[:fq] += values.map { |value| "!#{solr_field_from_field(field)}:#{value}" }
     end
    end
    solr_options[:sort] = convert_search_order(self.search_options[:order]) if self.search_options[:order]
    if self.search_options[:search].is_a?(Array)
      solr_options[:q] = self.search_options[:search].map { |query| "(#{query})" }.join(" AND ")
    end
    
    if self.search_options[:geo_center] && self.search_options[:geo_distance]
      solr_options[:pt] = "#{self.search_options[:geo_center][:lat]},#{self.search_options[:geo_center][:lng]}"
      solr_options[:d] = self.search_options[:geo_distance].to_f / Supernova::KM_TO_METER
      solr_options[:sfield] = solr_field_from_field(:location)
      solr_options[:fq] << "{!geofilt}"
    end
    if self.search_options[:select]
      self.search_options[:select] << :id
      solr_options[:fl] = self.search_options[:select].compact.map { |field| solr_field_from_field(field) }.join(",") 
    end
    solr_options[:fq] << "type:#{self.clazz}" if self.clazz
    
    if self.search_options[:pagination]
      solr_options[:rows] = per_page
      solr_options[:start] = (current_page - 1) * solr_options[:rows]
    end
    solr_options
  end
  
  def convert_search_order(order)
    asc_or_desc = nil
    field = solr_field_from_field(order)
    if order.match(/^(.*?) (asc|desc)/i)
      field = solr_field_from_field($1)
      asc_or_desc = $2
    end
    [field, asc_or_desc].compact.join(" ")
  end
  
  def solr_field_from_field(field)
    Supernova::SolrIndexer.solr_field_for_field_name_and_mapping(field, search_options[:attribute_mapping])
  end
  
  def fq_from_with(with)
    if with.blank?
      []
    else
      with.map do |key_or_condition, value|
        if key_or_condition.respond_to?(:solr_filter_for)
          key_or_condition.key = solr_field_from_field(key_or_condition.key)
          key_or_condition.solr_filter_for(value)
        else
          fq_filter_for_key_and_value(solr_field_from_field(key_or_condition), value)
        end
      end
    end
  end
  
  def fq_filter_for_key_and_value(key, value)
    "#{key}:#{value.is_a?(Range) ? "[#{value.first} TO #{value.last}]" : value}"
  end
  
  def build_docs(docs)
    docs.map do |hash|
      self.search_options[:build_doc_method] ? self.search_options[:build_doc_method].call(hash) : build_doc(hash)
    end
  end
  
  def build_doc_method(method)
    merge_search_options :build_doc_method, method
  end
  
  def build_doc(hash)
    return hash if !hash["type"].respond_to?(:constantize)
    doc = hash["type"].constantize.new
    doc.instance_variable_set("@solr_doc", hash)
    hash.each do |key, value|
      if key == "id"
        doc.id = value.to_s.split("/").last if doc.respond_to?(:id=)
      else
        doc.send(:"#{key}=", value) if doc.respond_to?(:"#{key}=")
      end
    end
    doc.instance_variable_set("@readonly", true)
    doc.instance_variable_set("@new_record", false)
    doc
  end
  
  def to_a
    response = Supernova::Solr.connection.get("select", :params => to_params)
    collection = Supernova::Collection.new(current_page, per_page, response["response"]["numFound"])
    collection.replace(build_docs(response["response"]["docs"]))
    collection
  end
end