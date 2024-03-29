require "spec_helper"

describe Supernova::SolrIndexer do
  let(:indexer_clazz) { Class.new(Supernova::SolrIndexer) }
  let(:db) { double("db", :query => [to_index]) }
  let(:to_index) { { :id => 1, :title => "Some Title"} }
  let(:file_stub) { double("file").as_null_object }
  let(:solr) { double("solr").as_null_object }
  let(:solr_index_response) { %(<int name="status">0</int>) }
  
  let(:indexer) do
    indexer = Supernova::SolrIndexer.new
    indexer.db = db
    indexer.stub!(:system).and_return true
    Kernel.stub!(:`).and_return solr_index_response
    indexer
  end
  
  let(:custom_indexer) { indexer_clazz.new }
  
  before(:each) do
    Supernova::Solr.url = "http://solr.xx:9333/solr"
    Supernova::Solr.stub!(:connection).and_return solr
    indexer_clazz.has(:title, :type => :text)
    indexer_clazz.has(:artist_id, :type => :integer)
    indexer_clazz.has(:description, :type => :text)
    indexer_clazz.has(:created_at, :type => :date)
    indexer_clazz.has(:indexed, :type => :boolean, :virtual => true)
  end
  
  before(:each) do
    File.stub!(:open).and_return file_stub
    Kernel.stub!(:`).and_return true
  end
  
  describe "#index_with_json_string" do
    let(:row1) { double("row1") }
    let(:row2) { double("row2") }
    let(:rows) { [row1, row2] }
    
    before(:each) do
      indexer.current_json_string = "{"
      indexer.stub!(:append_to_json_string)
    end
    
    it "calls append to string with all rows" do
      indexer.should_receive(:append_to_json_string).with(row1)
      indexer.should_receive(:append_to_json_string).with(row2)
      indexer.index_with_json_string(rows)
    end
    
    it "calls finalize_json_string" do
      indexer.should_receive(:finalize_json_string)
      indexer.index_with_json_string(rows)
    end
    
    it "calls post_json_string" do
      indexer.should_receive(:post_json_string)
      indexer.index_with_json_string(rows)
    end
  end
  
  describe "#post_json_string" do
    before(:each) do
      Typhoeus::Request.stub(:post)
    end
    
    it "posts the json string" do
      indexer.current_json_string = "some string"
      Typhoeus::Request.should_receive(:post).with("http://solr.xx:9333/solr/update/json?commit=true", :body => "some string", :headers => { "Content-type" => "application/json; charset=utf-8" }).and_return(double("rsp", :body => "text"))
      indexer.post_json_string
    end
    
    it "resets the current_json_string" do
      indexer.current_json_string = "some string"
      indexer.post_json_string
      indexer.current_json_string.should be_nil
    end
  end
  
  describe "#append_to_json_string" do
    it "creates a new string" do
      indexer.append_to_json_string({"a" => 1})
      indexer.current_json_string.should == %({\n"add":{"doc":{"a":1}})
    end
    
    it "removes nil values" do
      indexer.append_to_json_string({"a" => 1, "b" => nil})
      indexer.current_json_string.should == %({\n"add":{"doc":{"a":1}})
    end
    
    it "appends to the existing string" do
      indexer.append_to_json_string({"a" => 1})
      indexer.append_to_json_string({"b" => 2})
      indexer.current_json_string.should == %({\n"add":{"doc":{"a":1}},\n"add":{"doc":{"b":2}})
    end
  end
  
  describe "#finalize_json_string" do
    it "adds the last brackets" do
      indexer.append_to_json_string({"a" => 1})
      indexer.finalize_json_string
      indexer.current_json_string.should == %({\n"add":{"doc":{"a":1}}\n})
    end
  end
  
  describe "initialize" do
    it "sets all options" do
      options = { :database => { :database => "dynasty", :username => "dynasty_user" } }
      indexer = Supernova::SolrIndexer.new(options)
      indexer.options.should == options
    end
    
    it "sets all known attributes" do
      indexer = Supernova::SolrIndexer.new(:db => db)
      indexer.db.should == db
    end
    
    it "can be initialized with ids" do
      Supernova::SolrIndexer.new(:ids => [1, 2]).ids.should == [1, 2]
    end
    
    it "sets ids to all when nil" do
      Supernova::SolrIndexer.new.ids.should == :all
    end
    
    it "sets max_rows_to_direct_index to 100" do
      Supernova::SolrIndexer.new.max_rows_to_direct_index.should == 100
    end
  end
  
  describe "index!" do
    it "calls query_to_index" do
      indexer.should_receive(:query_to_index).and_return "some query"
      indexer.index!
    end
    
    it "calls index_query on query_to_index" do
      query = "some query"
      indexer.stub!(:query_to_index).and_return query
      indexer.should_receive(:index_query).with(query)
      indexer.index!
    end
  end
  
  describe "#map_for_solr" do
    let(:row) { { "a" => 1 } }
    
    before(:each) do
      indexer.stub!(:puts)
    end
    
    it "calls row_to_solr" do
      indexer.should_not_receive(:before_index)
      indexer.should_receive(:row_to_solr).with(row).and_return row
      indexer.map_for_solr(row)
    end
    
    it "prints a deprecation warning when using row_to_solr" do
      indexer.stub!(:row_to_solr).with(row).and_return row
      indexer.should_receive(:puts).with(/DEPRECATION WARNING: use before_index instead of row_to_solr! in/)
      indexer.map_for_solr(row)
    end
    
    it "calls before_index when row_to_solr is not defined" do
      row = { "a" => 1 }
      indexer.should_receive(:before_index).with(row).and_return row
      indexer.map_for_solr(row)
    end
    
    it "calls map_hash_keys_to_solr with result of row_to_solr" do
      dummy_row = double("dummy row")
      indexer.stub!(:row_to_solr).and_return dummy_row
      indexer.should_receive(:map_hash_keys_to_solr).with(dummy_row)
      indexer.map_for_solr({ "a" => 1 })
    end
    
    describe "with the index defining extra_attributes_from_record" do
      let(:index) { SolrOfferIndex.new }
      let(:offer_double) { double("Solr Offer", :id => 88).as_null_object }
      
      class SolrOfferIndex < Supernova::SolrIndexer
        clazz Offer
        has :created_at, :type => :date
        has :offer_id, :type => :integer
        
        def extra_attributes_from_record(doc)
          { :offer_code => "OFFER_#{doc.id}" }
        end
      end
      
      it "calls Supernova.build_ar_like_record with correct parameters" do
        Supernova.should_receive(:build_ar_like_record).and_return offer_double
        SolrOfferIndex.new("offer_id" => 77, "type" => "Offer").map_for_solr(row)
      end
      
      it "includes the original attributes" do
        index = SolrOfferIndex.new
        index.map_for_solr({ "a" => 2 })["a"].should == 2
      end
      
      it "includes the attributes from extra_attributes_from_record" do
        index = SolrOfferIndex.new
        index.map_for_solr({ "a" => 2, "id" => "88" })["offer_code"].should == "OFFER_88"
        hash = { :a => 1, "a" => 2 }
      end
    end
  end
  
  describe "validate_lat" do
    { nil => nil, 10 => 10.0, 90.1 => nil, 90 => 90, -90.1 => nil, -90 => -90 }.each do |from, to|
      it "converts #{from} to #{to}" do
        indexer.validate_lat(from).should == to
      end
    end
  end
  
  describe "validate_lng" do
    { nil => nil, 10 => 10.0, 180.1 => nil, 180 => 180, -180.1 => nil, -180 => -180 }.each do |from, to|
      it "converts #{from} to #{to}" do
        indexer.validate_lng(from).should == to
      end
    end
  end
  
  describe "#sql_column_from_field_and_type" do
    {
      [:title, :string] => "title AS title_s",
      [:count, :int] => "count AS count_i",
      [:test, :sint] => "test AS test_si",
      [:lat, :float] => "lat AS lat_f",
      [:text, :boolean] => "text AS text_b",
      [:loc, :location] => "loc AS loc_p",
      [:big_int, :double] => "big_int AS big_int_d",
      [:deleted_at, :date] => %(IF(deleted_at IS NULL, NULL, CONCAT(REPLACE(deleted_at, " ", "T"), "Z")) AS deleted_at_dt),
    }.each do |(field, type), name|
      it "maps #{field} with #{type} to #{name}" do
        indexer.sql_column_from_field_and_type(field, type).should == name
      end
    end
    
    it "raises an error when no mapping defined" do
      lambda {
        indexer.sql_column_from_field_and_type(:text, :rgne)
      }.should raise_error
    end
  end
  
  describe "#before_index" do
    it "returns the db row by default" do
      indexer.before_index("id" => 1).should == { "id" => 1 }
    end
  end
  
  describe "#query_db" do
    it "executes the query" do
      db.should_receive(:query).with("query", :as => :hash).and_return [to_index]
      indexer.query_db("query")
    end
    
    it "calls select_all when not responding to query" do
      old_mysql_double = double("old mysql double", :select_all => [])
      indexer.db = old_mysql_double
      old_mysql_double.should_receive(:select_all).with("query").and_return [to_index]
      indexer.query_db("query")
    end
  end
  
  describe "#debug" do
    it "prints a line when debug is enabled" do
      index = CustomSolrIndex.new(:debug => true)
      index.should_receive(:puts).with(/hello world/)
      index.debug "hello world"
    end
    
    it "does not print print a line when debug is not enabled" do
      index = CustomSolrIndex.new(:debug => false)
      index.should_not_receive(:puts)
      index.debug "hello world"
    end
    
    it "can be called with block and still returns the response" do
      index = CustomSolrIndex.new(:debug => true)
      index.should_receive(:puts).with(/some message/)
      res = index.debug "some message" do
        112
      end
      res.should == 112
    end
    
    it "includes the time in the debug output when placeholder found" do
      index = CustomSolrIndex.new(:debug => true)
      Benchmark.stub(:realtime).and_return 0.12345
      index.should_receive(:puts).with(/indexed in 0.123/)
      index.debug "indexed in %TIME%" do
        112
      end
    end
    
    it "replaces %COUNT% when responding to .count" do
      index = CustomSolrIndex.new(:debug => true)
      index.should_receive(:puts).with(/indexed 2/)
      index.debug "indexed %COUNT%" do
        [1, 2]
      end
    end
  end
  
  let(:index) { CustomSolrIndex.new }
  
  describe "#ids=" do
    it "sets the ids array" do
      index.ids = [2, 4]
      index.ids.should == [2, 4]
    end
    
    it "sets the @cached array to nil" do
      index.instance_variable_set("@cached", { :a => 1 })
      index.ids = [2, 4]
      index.instance_variable_get("@cached").should == {}
    end
  end
  
  describe "#cached" do
    it "returns the instance variable when set" do
      index.instance_variable_set("@cached", { :a => 1 })
      index.cached.should == { :a => 1 }
    end
    
    it "returns and initializes a new cached hash when nil" do
      index.instance_variable_set("@cached", nil)
      index.cached.should == {}
      index.instance_variable_get("@cached").should == {}
    end
  end
  
  describe "#map_hash_keys_to_solr" do
    class CustomSolrIndex < Supernova::SolrIndexer
      has :offer_id, :type => :integer
      has :lat, :type => :float
      has :lng, :type => :float
      has :created_at, :type => :date
      has :checkin_date, :type => :date
      has :indexed, :type => :boolean, :virtual => true
    end
    
    it "sets empty dates to nil" do
      CustomSolrIndex.new.map_hash_keys_to_solr("checkin_date" => nil)["checkin_date_dt"].should == nil
    end
    
    it "maps virtual fields" do
      CustomSolrIndex.new.map_hash_keys_to_solr("indexed" => true)["indexed_b"].should == true
    end
    
    it "maps fields with false as value" do
      CustomSolrIndex.new.map_hash_keys_to_solr("indexed" => false)["indexed_b"].should == false
    end
    
    it "maps float fields" do
      index = CustomSolrIndex.new
      index.map_hash_keys_to_solr("lat" => 49.0)["lat_f"].should == 49.0
    end
    
    it "maps time fields to iso8601" do
      index = CustomSolrIndex.new
      time = Time.parse("2011-02-03 11:20:30")
      index.map_hash_keys_to_solr("created_at" => time)["created_at_dt"].should == "2011-02-03T10:20:30Z"
    end
    
    it "maps date fields to iso8601" do
      date = Date.new(2011, 1, 2)
      CustomSolrIndex.new.map_hash_keys_to_solr("checkin_date" => date)["checkin_date_dt"].should == "2011-01-02T00:00:00Z"
    end
    
    it "sets the indexed_at time" do
      Time.stub!(:now).and_return Time.parse("2011-02-03T11:20:30Z")
      CustomSolrIndex.new.map_hash_keys_to_solr({})["indexed_at_dt"].should == "2011-02-03T11:20:30Z"
      Time.unstub!(:now)
    end
    
    it "adds the class as type when class set" do
      clazz = Class.new(Supernova::SolrIndexer)
      clazz.clazz Offer
      clazz.new.map_hash_keys_to_solr({})["type"].should == "Offer"
    end
    
    it "adds the table_name as prefix for id" do
      clazz = Class.new(Supernova::SolrIndexer)
      index = clazz.new
      index.stub(:table_name).and_return "people"
      index.map_hash_keys_to_solr({ "id" => 88 })["id"].should == "people/88"
    end
    
    it "sets the record id when table is set" do
      clazz = Class.new(Supernova::SolrIndexer)
      index = clazz.new
      index.stub(:table_name).and_return "people"
      index.map_hash_keys_to_solr({ "id" => 88 })["record_id_i"].should == 88
    end
    
    it "adds the sets the cla" do
      clazz = Class.new(Supernova::SolrIndexer)
      clazz.clazz Offer
      clazz.new.map_hash_keys_to_solr({})["type"].should == "Offer"
    end
  end
  
  describe "#rows" do
    let(:res) { double("result") }
    
    before(:each) do
      custom_indexer.stub(:query_db).and_return([])
    end
    
    it "calls query_db with correct query" do
      custom_indexer.should_receive(:query_db).with("some query").and_return res
      custom_indexer.rows("some query").should == res
    end
    
    it "uses the query_to_index when query is blank" do
      custom_indexer.should_receive(:query_to_index).and_return "some other query"
      custom_indexer.should_receive(:query_db).with("some other query").and_return res
      custom_indexer.rows.should == res
    end
  end
  
  describe "#solr_rows_to_index_for_query" do
    let(:result) {
      [
        { "title" => "Some Title", "artist_id" => 10 }
      ]
    }
    
    { "title_t" => "Some Title", "artist_id_i" => 10 }.each do |key, value|
      it "sets #{key} to #{value}" do
        custom_indexer.should_receive(:query_db).with("some query").and_return(result)
        custom_indexer.solr_rows_to_index_for_query("some query").first[key].should == value
      end
    end
    
    it "also maps virtual attributes" do
      hash = { "indexed" => true }
      query = "some query"
      custom_indexer.should_receive(:query_db).with(query).and_return([hash])
      custom_indexer.solr_rows_to_index_for_query(query).first["indexed_b"].should == true
    end
  end
  
  describe "#index_with_json" do
    it "calls index_with_json_string by default" do
      indexer.should_receive(:index_with_json_string).with([1])
      indexer.index_with_json([1])
    end
    
    it "calls index_with_json_file when asked to" do
      indexer.options[:use_json_file] = true
      indexer.should_receive(:index_with_json_file).with([1])
      indexer.index_with_json([1])
    end
  end
  
  describe "#index_rows" do
    let(:row1) { double("row1") }
    let(:row2) { double("row2") }
    let(:mapped1) { double("mapped 1") }
    let(:mapped2) { double("mapped 2") }
    
    before(:each) do
      custom_indexer.stub(:map_for_solr).with(row1).and_return(mapped1)
      custom_indexer.stub(:map_for_solr).with(row2).and_return(mapped2)
    end
    
    it "is callable" do
      custom_indexer.index_rows([])
    end
    
    it "calls map_for_solr on all rows" do
      custom_indexer.should_receive(:map_for_solr).with(row1).and_return(mapped1)
      custom_indexer.should_receive(:map_for_solr).with(row2).and_return(mapped2)
      custom_indexer.index_rows([row1, row2])
    end
    
    it "calls map_directly when number of rows < max_rows_to_direct_index" do
      custom_indexer.should_receive(:max_rows_to_direct_index).and_return 100
      custom_indexer.should_receive(:index_directly).with([mapped1, mapped2])
      custom_indexer.index_rows([row1, row2])
    end
    
    it "calls map_directly when number of rows < max_rows_to_direct_index" do
      custom_indexer.should_receive(:max_rows_to_direct_index).and_return 1
      custom_indexer.should_receive(:index_with_json).with([mapped1, mapped2])
      custom_indexer.index_rows([row1, row2])
    end
  end
  
  describe "#index_query" do
    let(:query) { %(SELECT CONCAT("user_", id) AS id, title FROM people WHERE type = 'User') }
    
    it "calls index_rows with result of query" do
      rows = [to_index]
      indexer.should_receive(:query_db).with(query).and_return rows
      indexer.should_receive(:index_rows).with(rows)
      indexer.index_query(query)
    end
  end
  
  describe "#index_with_json_file" do
    let(:rows) { [{ "b" => 2 }, { "a" => 1 }] }
    
    it "calls write_to_file on all rows" do
      indexer.should_receive(:write_to_file).with(rows.first)
      indexer.should_receive(:write_to_file).with(rows.at(1))
      indexer.stub!(:finish)
      indexer.index_with_json_file(rows)
    end

    it "calls finish" do
      indexer.should_receive(:finish)
      indexer.index_with_json_file(rows)
    end
  end
  
  describe "#index_directly" do
    before(:each) do
      Supernova::Solr.stub!(:connection).and_return solr
    end
    
    it "calls the correct add statement" do
      row1 = double("1")
      row2 = double("2")
      rows = [row1, row2]
      solr.should_receive(:add).with(row1)
      solr.should_receive(:add).with(row2)
      indexer.index_directly(rows)
    end
    
    it "calls commit" do
      solr.should_receive(:commit)
      indexer.index_directly([double("1")])
    end
    
    it "does not call commit when rows is empty" do
      solr.should_not_receive(:commit)
      indexer.index_directly([])
    end
  end
  
  describe "#index_file_path" do
    it "returns the set file_path" do
      indexer.index_file_path = "/some/path"
      indexer.index_file_path.should == "/some/path"
    end
    
    it "returns a random file path when not set" do
      Time.stub(:now).and_return Time.at(112233)
      indexer.index_file_path.should == "/tmp/index_file_112233.json"
    end
  end
  
  describe "#write_to_file" do
    describe "with the stream not being open" do
      it "opens a new stream" do
        indexer.index_file_path = "/tmp/some_path.json"
        File.should_receive(:open).with("/tmp/some_path.json", "w")
        indexer.write_to_file(to_index)
      end
      
      it "writes the opening brackets and the first line" do
        file_stub.should_receive(:puts).with("\{")
        file_stub.should_receive(:print).with do |str|
          str.should include("add")
          str.should include("\"title\":\"Some Title\"")
          str.should include("\"id\":1")
        end
        indexer.write_to_file(to_index)
      end
      
      it "only write fields which are not null" do
        file_stub.stub(:print)
        file_stub.should_not_receive(:print).with do |str|
          str.include?("text")
        end
        indexer.write_to_file(to_index.merge(:text => nil))
      end
      
      it "separates the first and the second line" do
        file_stub.should_receive(:puts).with("\{")
        file_stub.should_receive(:print).with(/\"add\":\{\"doc\"/)
        file_stub.should_receive(:print).with(%(,\n"add":{"doc":{"id":2}}))
        indexer.write_to_file(to_index)
        indexer.write_to_file({:id => 2})
      end
    end
    
    it "does not open a new file when already open" do
      indexer.instance_variable_set("@index_file_stream", file_stub)
      File.should_not_receive(:open)
      indexer.write_to_file(to_index)
    end
  end
  
  describe "#finish" do
    it "raises an error when stream not open" do
      lambda {
        indexer.finish
      }.should raise_error("nothing to index")
    end
    
    describe "with something being written" do
      it "writes closing bracket to file" do
        indexer.write_to_file(to_index)
        file_stub.should_receive(:puts).with("\}")
        indexer.finish
      end

      it "closes the stream" do
        indexer.write_to_file(to_index)
        file_stub.should_receive(:close)
        indexer.finish
      end
      
      it "calls do_index_file" do
        indexer.write_to_file(to_index)
        indexer.should_receive(:do_index_file)
        indexer.finish
      end
    end
  end
  
  describe "#do_index_file" do
    it "raises an error when solr_url not configues" do
      Supernova::Solr.url = nil
      lambda {
        Supernova::SolrIndexer.new.do_index_file
      }.should raise_error("solr not configured")
    end
    
    it "calls the correct curl command" do
      indexer = Supernova::SolrIndexer.new(:index_file_path => "/tmp/some_path.json", :local_solr => true)
      Kernel.should_receive(:`).with("curl -s 'http://solr.xx:9333/solr/update/json?commit=true\\&stream.file=/tmp/some_path.json'").and_return solr_index_response
      indexer.do_index_file(:local => true)
    end
    
    it "calls rm on file" do
      indexer = Supernova::SolrIndexer.new(:index_file_path => "/tmp/some_path.json", :local_solr => true)
      Kernel.should_receive(:`).with("curl -s 'http://solr.xx:9333/solr/update/json?commit=true\\&stream.file=/tmp/some_path.json'").and_return solr_index_response
      FileUtils.should_receive(:rm_f).with("/tmp/some_path.json")
      indexer.do_index_file(:local => true)
    end
    
    it "does not call rm when not successful" do
      indexer = Supernova::SolrIndexer.new(:index_file_path => "/tmp/some_path.json", :local_solr => true)
      Kernel.should_receive(:`).with("curl -s 'http://solr.xx:9333/solr/update/json?commit=true\\&stream.file=/tmp/some_path.json'").and_return %(<int name="status">1</int>)
      FileUtils.should_not_receive(:rm_f).with("/tmp/some_path.json")
      lambda {
        indexer.do_index_file(:local => true)
      }.should raise_error
    end
    
    it "executes the correct curl call when not local" do
      # curl 'http://localhost:8983/solr/update/json?commit=true' --data-binary @books.json -H 'Content-type:application/json'
      indexer.index_file_path = "/tmp/some_path.json"
      Kernel.should_receive(:`).with("cd /tmp && curl -s 'http://solr.xx:9333/solr/update/json?commit=true' --data-binary @some_path.json -H 'Content-type:application/json'").and_return solr_index_response
      indexer.do_index_file
    end
  end

  describe "define mappings" do
    let(:blank_indexer_clazz) { Class.new(Supernova::SolrIndexer) }
    
    it "has an empty array of field_definitions by default" do
      blank_indexer_clazz.field_definitions.should == {}
    end
    
    it "has adds filters to the field_definitions" do
      blank_indexer_clazz.has(:artist_id, :type => :integer, :sortable => true)
      blank_indexer_clazz.field_definitions.should == { :artist_id => { :type => :integer, :sortable => true } }
    end
    
    it "has can also be called with a symbol as argument and sets that to the type" do
      blank_indexer_clazz.has(:artist_id, :integer)
      blank_indexer_clazz.field_definitions.should == { :artist_id => { :type => :integer } }
    end
    
    it "clazz sets indexed class" do
      blank_indexer_clazz.clazz(Integer)
      blank_indexer_clazz.instance_variable_get("@clazz").should == Integer
    end
    
    it "does not change but return the clazz when nil" do
      blank_indexer_clazz.clazz(Integer)
      blank_indexer_clazz.clazz.should == Integer
    end
    
    it "allows setting the clazz to nil" do
      blank_indexer_clazz.clazz(Integer)
      blank_indexer_clazz.clazz(nil)
      blank_indexer_clazz.clazz.should be_nil
    end
    
    it "table_name sets the table name" do
      blank_indexer_clazz.table_name(:people)
      blank_indexer_clazz.instance_variable_get("@table_name").should == :people
    end
    
    it "table_name does not overwrite but return table_name when nil given" do
      blank_indexer_clazz.table_name(:people)
      blank_indexer_clazz.table_name.should == :people
    end
    
    it "allows setting the table_name to nil" do
      blank_indexer_clazz.table_name(:people)
      blank_indexer_clazz.table_name(nil).should be_nil
    end
  end
  
  describe "#default_mappings" do
    it "returns id when no class defined" do
      indexer_clazz.new.default_fields.should == ["id"]
    end
    
    it "adds type when class defined" do
      indexer_clazz.clazz Integer
      indexer_clazz.new.default_fields.should == ["id", %("Integer" AS type)]
    end
  end
  
  describe "#defined_fields" do
    let(:field_definitions) { { :title => { :type => :string } } }
    
    it "calls field_definitions" do
      indexer_clazz.should_receive(:field_definitions).and_return field_definitions
      custom_indexer.defined_fields
    end
    
    ["title", "artist_id", "description", "created_at"].each do |field|
      it "includes field #{field.inspect}" do
        custom_indexer.defined_fields.should include(field)
      end
    end
    
    it "does not include virtual fields" do
      clazz = Class.new(Supernova::SolrIndexer)
      clazz.has :location, :type => :location, :virtual => true
      clazz.has :title, :type => :string
      clazz.new.defined_fields.should == ["title"]
    end
  end
  
  describe "#table_name" do
    it "returns nil when no table_name defined on indexer class and no class defined" do
      Class.new(Supernova::SolrIndexer).new.table_name.should be_nil
    end
    
    it "returns nil when no table_name defined on indexer class and class does not respond to table name" do
      clazz = Class.new(Supernova::SolrIndexer)
      clazz.clazz(Integer)
      clazz.new.table_name.should be_nil
    end
    
    it "returns the table name defined in indexer class" do
      clazz = Class.new(Supernova::SolrIndexer)
      clazz.table_name(:some_table)
      clazz.new.table_name.should == :some_table
    end
    
    it "returns the table name ob class when responding to table_name" do
      model_clazz = double("clazz", :table_name => "model_table")
      clazz = Class.new(Supernova::SolrIndexer)
      clazz.clazz(model_clazz)
      clazz.new.table_name.should == "model_table"
    end
  end

  describe "#query_to_index" do
    before(:each) do
      @indexer_clazz = Class.new(Supernova::SolrIndexer)
      @indexer_clazz.clazz Integer
      @indexer_clazz.table_name "integers"
      @indexer = @indexer_clazz.new
    end
    
    it "raises an error when table_name returns nil" do
      @indexer_clazz.clazz(nil)
      @indexer_clazz.table_name(nil)
      @indexer.should_receive(:table_name).and_return nil
      lambda {
        @indexer.query_to_index
      }.should raise_error("no table_name defined")
    end
    
    it "returns a string" do
      @indexer.query_to_index.should be_an_instance_of(String)
    end
    
    it "does not include a where when ids is nil" do
      @indexer.query_to_index.should_not include("WHERE")
    end
    
    it "does include a where when ids are present" do
      @indexer_clazz.new(:ids => %w(1 2)).query_to_index.should include("WHERE id IN (1, 2)")
    end
    
    it "calls and includes select_fields" do
      @indexer.should_receive(:select_fields).and_return %w(a c)
      @indexer.query_to_index.should include("SELECT a, c FROM integers")
    end
  end
  
  describe "#select_fields" do
    it "joins default_fields with defined_fields" do
      default = double("default fields")
      defined = double("defined fields")
      indexer.should_receive(:default_fields).and_return [default]
      indexer.should_receive(:defined_fields).and_return [defined]
      indexer.select_fields.should == [default, defined]
    end
  end
  
  describe "SolrIndexer.select_fields" do
    it "returns the keys of the field definitions" do
      Supernova::SolrIndexer.should_receive(:field_definitions).and_return(
        { :title => { :type => :string }, :popularity => { :type => :integer } }
      )
      Supernova::SolrIndexer.select_fields.map(&:to_s).sort.should == %w(popularity title)
    end
    
    it "does not include virtual attributes" do
      Supernova::SolrIndexer.should_receive(:field_definitions).and_return(
        { :title => { :type => :string }, :popularity => { :type => :integer }, :is_deleted => { :virtual => true, :type => :integer } }
      )
      Supernova::SolrIndexer.select_fields.map(&:to_s).sort.should == %w(popularity title)
    end
  end
  
  describe "#method_missing" do
    it "returns a new supernova criteria" do
      indexer_clazz.where(:a => 1).should be_an_instance_of(Supernova::SolrCriteria)
    end
    
    it "sets the correct clazz" do
      indexer_clazz = Class.new(Supernova::SolrIndexer)
      indexer_clazz.clazz(String)
      indexer_clazz.where(:a => 1).clazz.should == String
    end
    
    it "adds the attribute_mapping" do
      indexer_clazz.where(:a => 1).search_options[:attribute_mapping].should == {
        :artist_id=>{:type=>:integer}, :title=>{:type=>:text}, :created_at=>{:type=>:date}, :description=>{:type=>:text},
        :indexed => {:type => :boolean, :virtual => true } 
      }
    end
  end
  
  describe "#named_search_scope" do
    it "returns the correct scope" do
      indexer_clazz.named_search_scope :published do
        where(:public => true)
      end
      indexer_clazz.published.search_options[:attribute_mapping].should == {
        :artist_id=>{:type=>:integer}, :title=>{:type=>:text}, :created_at=>{:type=>:date}, :description=>{:type=>:text}, 
        :indexed => {:type => :boolean, :virtual => true } 
      }
    end
    
    it "works with attribute mappings" do
      indexer_clazz.named_search_scope :with_title do
        where(:title.ne => nil)
      end
      indexer_clazz.with_title.to_params[:fq].should include("title_t:[* TO *]")
    end
    
    it "allows chaining of named scopes" do
      indexer_clazz.named_search_scope :with_title do
        where(:title.ne => nil)
      end
      
      indexer_clazz.named_search_scope :with_description do
        where(:description.ne => nil)
      end
      fqs = indexer_clazz.with_description.with_title.to_params[:fq]
      fqs.should include("description_t:[* TO *]")
      fqs.should include("title_t:[* TO *]")
    end
  end
  
  describe "#suffix_from_type" do
    it "returns the correct field for string_array" do
      Supernova::SolrIndexer.suffix_from_type(:string_array).should == :ms
    end
  end
  
  describe "#solr_field_for_field_name_and_mapping" do
    let(:mapping) do 
      { 
        :artist_name => { :type => :string },
        :artist_id => { :type => :integer },
      }
    end
    
    { 
      :artist_name => "artist_name_s", "artist_name" => "artist_name_s", 
      :artist_id => "artist_id_i", :popularity => "popularity" 
    }.each do |from, to|
      it "maps #{from} to #{to}" do
        Supernova::SolrIndexer.solr_field_for_field_name_and_mapping(from, mapping).should == to
      end
    end
    
    it "returns the original field when mapping is nil" do
      Supernova::SolrIndexer.solr_field_for_field_name_and_mapping(:artist, nil).should == "artist"
    end
  end

  describe "#solr_url" do
    it "strips slashes from defined solr url" do
      Supernova::Solr.url = "http://solr.xx:9333/solr/"
      indexer.solr_url.should == "http://solr.xx:9333/solr"
    end
  end
end
