require 'spec_helper'

describe Supernova::SolrCriteria do
  let(:criteria) { Supernova::SolrCriteria.new }
  let(:rsolr) { double("rsolr").as_null_object }
  let(:docs) do
    [
      {"popularity"=>10, "location"=>"47,11", "text"=>"Hans Meyer", "id"=>"offers/1", "enabled"=>false, "user_id"=>1, "type"=>"Offer"}, 
      {"popularity"=>1, "location"=>"46.9981112912042,11.6587158814378", "text"=>"Marek Mintal", "id"=>"offers/2", "enabled"=>true, "user_id"=>2, "type"=>"Offer"}
    ]
  end
  let(:solr_response) do
    {
      "response"=>{"start"=>0, "docs"=>docs, "numFound"=>2}, "responseHeader"=>{"QTime"=>4, "params"=>{"fq"=>"type:Offer", "q"=>"*:*", "wt"=>"ruby"}, "status"=>0}
    }
  end
  
  before(:each) do
    Supernova::Solr.stub!(:connection).and_return rsolr
  end
  
  describe "#fq_from_with" do
    it "returns the correct filter for with ranges" do
      criteria.fq_from_with(:user_id => Range.new(10, 12)).should == ["user_id:[10 TO 12]"]
    end
    
    it "returns the correct filter for not queries" do
      criteria.fq_from_with(:user_id.not => nil).should == ["user_id:[* TO *]"]
    end
  end
  
  describe "#to_params" do
    it "returns a Hash" do
      criteria.to_params.should be_an_instance_of(Hash)
    end
    
    it "sets the correct filters" do
      criteria.with(:title => "Hans Maulwurf", :playings => 10).to_params[:fq].sort.should == ["playings:10", "title:Hans Maulwurf"]
    end
    
    it "allways includes some query" do
      criteria.with(:a => 1).to_params[:q].should == "*:*"
    end
    
    it "sets the order field" do
      criteria.order("title").to_params[:sort].should == "title"
    end
    
    it "sets search correct search query" do
      criteria.search("some query").to_params[:q].should == "(some query)"
    end
    
    it "joins the search terms with AND" do
      criteria.search("some", "query").to_params[:q].should == "(some) AND (query)"
    end
    
    it "adds a filter on type when clazz set" do
      Supernova::SolrCriteria.new(Offer).to_params[:fq].should == ["type:#{Offer}"]
    end
    
    it "does not add a filter on type when clazz is nil" do
      criteria.to_params[:fq].should == []
    end
    
    it "sets the correct select filters when present" do
      criteria.select(:user_id).select(:user_id).select(:enabled).to_params[:fl].should == "user_id,enabled,id"
    end
    
    it "adds all without filters" do
      criteria.without(:user_id => 1).to_params[:fq].should == ["!user_id:1"]
      criteria.without(:user_id => 1).without(:user_id => 1).without(:user_id => 2).to_params[:fq].sort.should == ["!user_id:1", "!user_id:2"]
    end
    
    describe "with a nearby search" do
      let(:nearby_criteria) { Supernova::SolrCriteria.new.near(47, 11).within(10.kms) }
      
      it "sets the correct center" do
        nearby_criteria.to_params[:pt].should == "47.0,11.0"
      end
      
      it "sets the correct distance" do
        nearby_criteria.to_params[:d].should == 10.0
      end
      
      it "sets the sfield to location" do
        nearby_criteria.to_params[:sfield].should == :location
      end
      
      it "sets the fq field to {!geofilt}" do
        nearby_criteria.to_params[:fq].should == ["{!geofilt}"]
      end
    end
    
    describe "pagination" do
      it "sets the correct rows" do
        criteria.paginate(:page => 1, :per_page => 10).to_params[:rows].should == 10
      end
      
      it "sets the correct start when page is nil" do
        criteria.paginate(:per_page => 10).to_params[:start].should == 0
      end
      
      it "sets the correct start when page is 1" do
        criteria.paginate(:per_page => 10, :page => 1).to_params[:start].should == 0
      end
      
      it "sets the correct start when page is 1" do
        criteria.paginate(:per_page => 10, :page => 2).to_params[:start].should == 10
      end
    end
  end

  describe "#to_a" do
    let(:params) { double("params") }
    
    before(:each) do
      criteria.stub(:to_params).and_return params
      rsolr.stub!(:get).and_return solr_response
    end
    
    it "calls to_params" do
      criteria.should_receive(:to_params).and_return params
      criteria.to_a
    end
    
    it "calls get with select and params" do
      rsolr.should_receive(:get).with("select", :params => params).and_return solr_response
      criteria.to_a
    end
    
    it "returns a Supernova::Collection" do
      criteria.to_a.should be_an_instance_of(Supernova::Collection)
    end
    
    it "sets the correct page when page is nil" do
      criteria.to_a.current_page.should == 1
    end
    
    it "sets the correct page when page is 1" do
      criteria.paginate(:page => 1).to_a.current_page.should == 1
    end
    
    it "sets the correct page when page is 2" do
      criteria.paginate(:page => 2).to_a.current_page.should == 2
    end
    
    it "sets the correct per_page when zero" do
      criteria.paginate(:page => 2, :per_page => nil).to_a.per_page.should == 25
    end
    
    it "sets the custom per_page when given" do
      criteria.paginate(:page => 2, :per_page => 10).to_a.per_page.should == 10
    end
    
    it "sets the correct total_entries" do
      criteria.paginate(:page => 2, :per_page => 10).to_a.total_entries.should == 2
    end
    
    it "calls build_docs with returned docs" do
      criteria.should_receive(:build_docs).with(docs).and_return []
      criteria.to_a
    end
    
    it "calls replace on collection wit returned docs" do
      col = double("collection")
      Supernova::Collection.stub!(:new).and_return col
      built_docs = double("built docs")
      criteria.stub!(:build_docs).and_return built_docs
      col.should_receive(:replace).with(built_docs)
      criteria.to_a
    end
  end
  
  describe "#build_docs" do
    it "returns an array" do
      criteria.build_docs([]).should == []
    end
    
    it "returns the correct amount of docs" do
      criteria.build_docs(docs).length.should == 2
    end
    
    it "returns the correct classes" do
      docs = [ { "id" => "hosts/7", "type" => "Host" }, { "id" => "offers/1", "type" => "Offer" }]
      criteria.build_docs(docs).map(&:class).should == [Host, Offer]
    end
    
    it "calls build_doc on all returnd docs" do
      doc1 = double("doc1")
      doc2 = double("doc2")
      docs = [doc1, doc2]
      criteria.should_receive(:build_doc).with(doc1)
      criteria.should_receive(:build_doc).with(doc2)
      criteria.build_docs(docs)
    end
    
    it "uses a custom mapper when build_doc_method is set" do
      doc1 = { "a" => 1 }
      meth = lambda { |row| row.to_a }
      criteria.build_doc_method(meth).build_docs([doc1]).should == [[["a", 1]]]
    end
  end
  
  describe "#build_doc" do
    { "Offer" => Offer, "Host" => Host }.each do |type, clazz|
      it "returns the #{clazz} for #{type.inspect}" do
        criteria.build_doc("type" => type).should be_an_instance_of(clazz)
      end
    end
    
    { :popularity => 10, :enabled => false, :id => 1 }.each do |key, value|
      it "sets #{key} to #{value}" do
        doc = criteria.build_doc("type" => "Offer", "some_other" => "Test", "id" => "offers/1", "enabled" => false, "popularity" => 10)
        doc.send(key).should == value
      end
    end
    
    it "sets the original solr_doc" do
      solr_doc = { "type" => "Offer", "id" => "offers/id" }
      criteria.build_doc(solr_doc).instance_variable_get("@solr_doc").should == solr_doc
    end
    
    it "should be readonly" do
      criteria.build_doc(docs.first).should be_readonly
    end
    
    it "should not be a new record" do
      criteria.build_doc(docs.first).should_not be_a_new_record
    end
    
    class MongoOffer
      attr_accessor :id
    end
    
    it "would also work with mongoid ids" do
      criteria.build_doc("type" => "MongoOffer", "id" => "offers/4df08c30f3b0a72e7c227a55").id.should == "4df08c30f3b0a72e7c227a55"
    end
    
    it "uses OpenStruct when type is not given" do
      doc = criteria.build_doc("id" => "offers/4df08c30f3b0a72e7c227a55")
      doc.should be_an_instance_of(Hash)
      doc["id"].should == "offers/4df08c30f3b0a72e7c227a55"
    end
  end
  
  describe "#current_page" do
    it "returns 1 when pagiantion is not set" do
      criteria.current_page.should == 1
    end
    
    it "returns 1 when page is set to nil" do
      criteria.paginate(:page => nil).current_page.should == 1
    end
    
    it "returns 1 when page is set to nil" do
      criteria.paginate(:page => 1).current_page.should == 1
    end
    
    it "returns 1 when page is set to nil" do
      criteria.paginate(:page => 0).current_page.should == 1
    end
    
    it "returns 2 when page is set to 2" do
      criteria.paginate(:page => 2).current_page.should == 2
    end
  end
  
  describe "#per_page" do
    it "returns 25 when nothing set" do
      criteria.per_page.should == 25
    end
    
    it "returns 25 when set to nil" do
      criteria.paginate(:page => 3, :per_page => nil).per_page.should == 25
    end
    
    it "returns 25 when set to 0" do
      criteria.paginate(:page => 3, :per_page => 0).per_page.should == 25
    end
    
    it "returns the custom value when set" do
      criteria.paginate(:page => 3, :per_page => 10).per_page.should == 10
    end
  end
end
