require "spec_helper"

describe Supernova::SolrIndexer do
  
  let(:db) { double("db", :query => [to_index]) }
  let(:to_index) { { :id => 1, :title => "Some Title"} }
  let(:file_stub) { double("file").as_null_object }
  
  let(:indexer) {
    indexer = Supernova::SolrIndexer.new
    indexer.db = db
    Supernova::Solr.url = "http://solr.xx:9333/solr"
    indexer.stub!(:system).and_return true
    indexer
  }
  
  before(:each) do
    File.stub!(:open).and_return file_stub
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
      indexer.should_receive(:system).with("curl -s 'http://solr.xx:9333/solr/update/json?commit=true\\&stream.file=/tmp/some_path.json'")
      indexer.do_index_file(:local => true)
    end
    
    it "executes the correct curl call when not local" do
      # curl 'http://localhost:8983/solr/update/json?commit=true' --data-binary @books.json -H 'Content-type:application/json'
      indexer.index_file_path = "/tmp/some_path.json"
      indexer.should_receive(:system).with("cd /tmp && curl -s 'http://solr.xx:9333/solr/update/json?commit=true' --data-binary @some_path.json -H 'Content-type:application/json'")
      indexer.do_index_file
    end
  end
end
