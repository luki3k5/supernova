require "json"

class Supernova::SolrIndexer
  attr_accessor :options, :db
  attr_writer :index_file_path
  
  def initialize(options = {})
    options.each do |key, value|
      self.send(:"#{key}=", value) if self.respond_to?(:"#{key}=")
    end
    self.options = options
  end
  
  def query_db(query)
    db.send(db.respond_to?(:query) ? :query : :select_all, query)
  end
  
  def index_query(query)
    query_db(query).each do |row|
      yield(row) if block_given?
      write_to_file(row)
    end
    finish
  end
  
  def index_file_path
    @index_file_path ||= File.expand_path("/tmp/index_file_#{Time.now.to_i}.json")
  end
  
  def write_to_file(to_index)
    prefix = ",\n"
    if !stream_open?
      index_file_stream.puts "{"
      prefix = nil
    end
    filtered = to_index.inject({}) do |hash, (key, value)|
      hash[key] = value if value.to_s.strip.length > 0
      hash
    end
    index_file_stream.print(%(#{prefix}"add":#{({:doc => filtered}).to_json}))
  end
  
  def finish
    raise "nothing to index" if !stream_open?
    index_file_stream.puts("\}")
    index_file_stream.close
    do_index_file
  end
  
  def stream_open?
    !@index_file_stream.nil?
  end
  
  def index_file_stream
    @index_file_stream ||= File.open(index_file_path, "w")
  end
  
  def solr_url
    Supernova::Solr.url
  end
  
  def do_index_file(options = {})
    raise "solr not configured" if solr_url.nil?
    cmd = if options[:local]
      %(curl -s '#{solr_url}/update/json?commit=true\\&stream.file=#{index_file_path}')
    else
      %(cd #{File.dirname(index_file_path)} && curl -s '#{solr_url}/update/json?commit=true' --data-binary @#{File.basename(index_file_path)} -H 'Content-type:application/json')
    end
    system(cmd)
  end
end