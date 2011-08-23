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
    
    if self.search_options[:facets]
      solr_options[:facet] = true
      solr_options["facet.field"] = self.search_options[:facets].compact.map { |field| solr_field_from_field(field) }
    end
    
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
  
  def reverse_lookup_solr_field(solr_field)
    if search_options[:attribute_mapping]
      search_options[:attribute_mapping].each do |field, options|
        return field if solr_field.to_s == solr_field_from_field(field)
      end
    end
    solr_field
  end
  
  def fq_from_with(with)
    if with.blank?
      []
    else
      with.map do |key_or_condition, values|
        values_from_key_or_condition_and_values(key_or_condition, values).map do |value|
          if key_or_condition.respond_to?(:solr_filter_for)
            key_or_condition.key = solr_field_from_field(key_or_condition.key)
            key_or_condition.solr_filter_for(value)
          else
            fq_filter_for_key_and_value(solr_field_from_field(key_or_condition), value)
          end
        end
      end.flatten
    end
  end
  
  def values_from_key_or_condition_and_values(key_or_condition, values)
    if key_or_condition.is_a?(Supernova::Condition) && values.is_a?(Array) && [:nin, :in].include?(key_or_condition.type)
      [values]
    else
      [values].flatten
    end
  end
  
  def fq_filter_for_key_and_value(key, value)
    if value.nil?
      "!#{key}:[* TO *]"
    elsif value.is_a?(Range)
      "#{key}:[#{value_for_fq_filter(value.first)} TO #{value_for_fq_filter(value.last)}]"
    else
      "#{key}:#{value_for_fq_filter(value)}"
    end
  end
  
  def value_for_fq_filter(value)
    if value.is_a?(Date)
      Time.utc(value.year, value.month, value.day).iso8601
    else
      value
    end
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
    if hash["type"].respond_to?(:constantize)
      Supernova.build_ar_like_record(hash["type"].constantize, convert_doc_attributes(hash), hash)
    else
      hash
    end
  end
  
  # called in build doc, all hashes have strings as keys!!!
  def convert_doc_attributes(hash)
    converted_hash = hash.inject({}) do |ret, (key, value)|
      if key == "id"
        ret["id"] = value.to_s.split("/").last
      else
        ret[reverse_lookup_solr_field(key).to_s] = value
      end
      ret
    end
    self.select_fields.each do |select_field|
      converted_hash[select_field.to_s] = nil if !converted_hash.has_key?(select_field.to_s)
    end
    converted_hash
  end
  
  def select_fields
    if self.search_options[:select].present?
      self.search_options[:select]
    else
      self.search_options[:named_scope_class].respond_to?(:select_fields) ? self.search_options[:named_scope_class].select_fields : []
    end
  end
  
  def set_first_responding_attribute(doc, solr_key, value)
    [reverse_lookup_solr_field(solr_key), solr_key].each do |key|
      meth = :"#{key}="
      if doc.respond_to?(meth)
        doc.send(meth, value)
        return
      end
    end
  end
  
  def hashify_facets_from_response(response)
    if response["facet_counts"] && response["facet_counts"]["facet_fields"]
      response["facet_counts"]["facet_fields"].inject({}) do |hash, (key, values)|
        hash[reverse_lookup_solr_field(key)] = Hash[*values]
        hash
      end
    end
  end
  
  def execute
    response = Supernova::Solr.connection.post("select", :data => to_params)
    collection = Supernova::Collection.new(current_page, per_page, response["response"]["numFound"])
    collection.original_response = response
    collection.facets = hashify_facets_from_response(response)
    collection.replace(build_docs(response["response"]["docs"]))
    collection
  end
end