require "spec_helper"

describe Supernova::SolrIndexer do
  let(:indexer_clazz) { Class.new(Supernova::SolrIndexer) }
  let(:db) { double("db", :query => [to_index]) }
  let(:to_index) { { :id => 1, :title => "Some Title"} }
  let(:file_stub) { double("file").as_null_object }
  
  let(:indexer) do
    indexer = Supernova::SolrIndexer.new
    indexer.db = db
    Supernova::Solr.url = "http://solr.xx:9333/solr"
    indexer.stub!(:system).and_return true
    indexer
  end
  
  let(:custom_indexer) { indexer_clazz.new }
  
  before(:each) do
    indexer_clazz.has(:title, :type => :text)
    indexer_clazz.has(:artist_id, :type => :integer)
    indexer_clazz.has(:description, :type => :text)
    indexer_clazz.has(:created_at, :type => :date)
  end
  
  before(:each) do
    File.stub!(:open).and_return file_stub
    Kernel.stub!(:`).and_return true
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
    
    it "calls row_to_solr with all returned rows from sql" do
      row1 = double("row1")
      row2 = double("row2")
      indexer.stub!(:query).and_return [row1, row2]
      indexer.stub!(:query_to_index).and_return "some query"
      indexer.should_receive(:row_to_solr).with(row1)
      indexer.stub!(:index_query).and_yield(row1)
      indexer.index!
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
  
  describe "#row_to_solr" do
    it "returns the db row by default" do
      indexer.row_to_solr("id" => 1).should == { "id" => 1 }
    end
  end
  
  describe "#query_db" do
    it "executes the query" do
      db.should_receive(:query).with("query").and_return [to_index]
      indexer.query_db("query")
    end
    
    it "calls select_all when not responding to query" do
      old_mysql_double = double("old mysql double", :select_all => [])
      indexer.db = old_mysql_double
      old_mysql_double.should_receive(:select_all).with("query").and_return [to_index]
      indexer.query_db("query")
    end
  end
  
  describe "#index_query" do
    let(:query) { %(SELECT CONCAT("user_", id) AS id, title FROM people WHERE type = 'User') }
    
    it "executes the query" do
      indexer.should_receive(:query_db).with(query).and_return [to_index]
      indexer.index_query(query)
    end
    
    it "calls write_to_file on all rows" do
      rows = [double("1"), double("2")]
      indexer.stub(:query_db).and_return rows
      indexer.should_receive(:write_to_file).with(rows.first)
      indexer.should_receive(:write_to_file).with(rows.at(1))
      indexer.stub!(:finish)
      indexer.index_query(query)
    end
    
    it "calls finish" do
      indexer.should_receive(:finish)
      indexer.index_query(query)
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
        file_stub.should_receive(:print).with("\"add\":{\"doc\":{\"title\":\"Some Title\",\"id\":1}}")
        indexer.write_to_file(to_index)
      end
      
      it "only write fields which are not null" do
        file_stub.should_receive(:print).with("\"add\":{\"doc\":{\"title\":\"Some Title\",\"id\":1}}")
        indexer.write_to_file(to_index.merge(:text => nil))
      end
      
      it "separates the first and the second line" do
        file_stub.should_receive(:puts).with("\{")
        file_stub.should_receive(:print).with("\"add\":{\"doc\":{\"title\":\"Some Title\",\"id\":1}}")
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
      indexer.index_file_path = "/tmp/some_path.json"
      Kernel.should_receive(:`).with("curl -s 'http://solr.xx:9333/solr/update/json?commit=true\\&stream.file=/tmp/some_path.json'")
      indexer.do_index_file(:local => true)
    end
    
    it "executes the correct curl call when not local" do
      # curl 'http://localhost:8983/solr/update/json?commit=true' --data-binary @books.json -H 'Content-type:application/json'
      indexer.index_file_path = "/tmp/some_path.json"
      Kernel.should_receive(:`).with("cd /tmp && curl -s 'http://solr.xx:9333/solr/update/json?commit=true' --data-binary @some_path.json -H 'Content-type:application/json'")
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
    
    ["title AS title_t", "artist_id AS artist_id_i", "description AS description_t", 
      %(IF(created_at IS NULL, NULL, CONCAT(REPLACE(created_at, " ", "T"), "Z")) AS created_at_dt)
    ].each do |field|
      it "includes field #{field.inspect}" do
        custom_indexer.defined_fields.should include(field)
      end
    end
    
    it "does not include virtual fields" do
      clazz = Class.new(Supernova::SolrIndexer)
      clazz.has :location, :type => :location, :virtual => true
      clazz.has :title, :type => :string
      clazz.new.defined_fields.should == ["title AS title_s"]
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
        :artist_id=>{:type=>:integer}, :title=>{:type=>:text}, :created_at=>{:type=>:date}, :description=>{:type=>:text}
      }
    end
  end
  
  describe "#named_search_scope" do
    it "returns the correct scope" do
      indexer_clazz.named_search_scope :published do
        where(:public => true)
      end
      indexer_clazz.published.search_options[:attribute_mapping].should == {
        :artist_id=>{:type=>:integer}, :title=>{:type=>:text}, :created_at=>{:type=>:date}, :description=>{:type=>:text}
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
end
