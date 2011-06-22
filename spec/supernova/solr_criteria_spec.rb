require 'spec_helper'
require "ostruct"

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
    
    it "uses a mapped field for order" do
      criteria.attribute_mapping(:title => { :type => :string }).order("title").to_params[:sort].should == "title_s"
    end
    
    %w(asc desc).each do |order|
      it "uses a mapped field for order even when #{order} is present" do
        criteria.attribute_mapping(:title => { :type => :string }).order("title #{order}").to_params[:sort].should == "title_s #{order}"
      end
    end
    
    
    it "sets search correct search query" do
      criteria.search("some query").to_params[:q].should == "(some query)"
    end
    
    it "joins the search terms with AND" do
      criteria.search("some", "query").to_params[:q].should == "(some) AND (query)"
    end
    
    # fix me: use type_s
    it "adds a filter on type when clazz set" do
      Supernova::SolrCriteria.new(Offer).to_params[:fq].should == ["type:#{Offer}"]
    end
    
    it "does not add a filter on type when clazz is nil" do
      criteria.to_params[:fq].should == []
    end
    
    it "sets the correct select filters when present" do
      criteria.select(:user_id).select(:user_id).select(:enabled).to_params[:fl].should == "user_id,enabled,id"
    end
    
    it "uses mapped fields for select" do
      mapping = {
        :user_id => { :type => :integer },
        :enabled => { :type => :boolean }
      }
      criteria.attribute_mapping(mapping).select(:user_id, :enabled).to_params[:fl].should == "user_id_i,enabled_b,id"
    end
    
    it "adds all without filters" do
      criteria.without(:user_id => 1).to_params[:fq].should == ["!user_id:1"]
      criteria.without(:user_id => 1).without(:user_id => 1).without(:user_id => 2).to_params[:fq].sort.should == ["!user_id:1", "!user_id:2"]
    end
    
    it "uses mapped fields for without" do
      criteria.attribute_mapping(:user_id => { :type => :integer }).without(:user_id => 1).to_params[:fq].should == ["!user_id_i:1"]
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
        nearby_criteria.to_params[:sfield].should == "location"
      end
      
      it "uses the mapped field when mapping defined" do
        nearby_criteria.attribute_mapping(:location => { :type => :location }).to_params[:sfield].should == "location_p"
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
    
    describe "with attribute mapping" do
      it "uses the mapped fields" do
        criteria.attribute_mapping(:artist_name => { :type => :string }).where(:artist_name => "test").to_params[:fq].should == ["artist_name_s:test"]
      end
      
      it "uses the mapped fields for all criteria queries" do
        criteria.attribute_mapping(:artist_name => { :type => :string }).where(:artist_name.ne => nil).to_params[:fq].should == ["artist_name_s:[* TO *]"]
      end
      
      it "uses the column when no mapping defined" do
        criteria.where(:artist_name => "test").to_params[:fq].should == ["artist_name:test"]
      end
    end
  end
  
  describe "#solr_field_from_field" do
    it "returns the field when no mappings defined" do
      criteria.solr_field_from_field(:artist_name).should == "artist_name"
    end
    
    it "returns the mapped field when mapping found" do
      criteria.attribute_mapping(:artist_name => { :type => :string }).solr_field_from_field(:artist_name).should == "artist_name_s"
    end
  end

  describe "#execute" do
    let(:params) { double("params") }
    
    before(:each) do
      criteria.stub(:to_params).and_return params
      rsolr.stub!(:post).and_return solr_response
    end
    
    it "calls to_params" do
      criteria.should_receive(:to_params).and_return params
      criteria.execute
    end
    
    it "calls get with select and params" do
      rsolr.should_receive(:post).with("select", :data => params).and_return solr_response
      criteria.execute
    end
    
    it "returns a Supernova::Collection" do
      criteria.execute.should be_an_instance_of(Supernova::Collection)
    end
    
    it "sets the correct page when page is nil" do
      criteria.execute.current_page.should == 1
    end
    
    it "sets the correct page when page is 1" do
      criteria.paginate(:page => 1).execute.current_page.should == 1
    end
    
    it "sets the correct page when page is 2" do
      criteria.paginate(:page => 2).execute.current_page.should == 2
    end
    
    it "sets the correct per_page when zero" do
      criteria.paginate(:page => 2, :per_page => nil).execute.per_page.should == 25
    end
    
    it "sets the custom per_page when given" do
      criteria.paginate(:page => 2, :per_page => 10).execute.per_page.should == 10
    end
    
    it "sets the correct total_entries" do
      criteria.paginate(:page => 2, :per_page => 10).execute.total_entries.should == 2
    end
    
    it "calls build_docs with returned docs" do
      criteria.should_receive(:build_docs).with(docs).and_return []
      criteria.execute
    end
    
    it "calls replace on collection wit returned docs" do
      col = double("collection")
      Supernova::Collection.stub!(:new).and_return col
      built_docs = double("built docs")
      criteria.stub!(:build_docs).and_return built_docs
      col.should_receive(:replace).with(built_docs)
      criteria.execute
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
    class OfferIndex < Supernova::SolrIndexer
      has :enabled, :type => :boolean
      has :popularity, :type => :integer
      has :is_deleted, :type => :boolean, :virtual => true
      clazz Offer
    end
    
    
    { "Offer" => Offer, "Host" => Host }.each do |type, clazz|
      it "returns the #{clazz} for #{type.inspect}" do
        criteria.build_doc("type" => type).should be_an_instance_of(clazz)
      end
    end
    
    it "calls convert_doc_attributes" do
      row = { "type" => "Offer", "id" => "offers/1" }
      criteria.should_receive(:convert_doc_attributes).with(row).and_return row
      criteria.build_doc(row)
    end
    
    it "returns the original hash when no type given" do
      type = double("type")
      row = { "id" => "offers/1", "type" => type }
      type.should_receive(:respond_to?).with(:constantize).and_return false
      criteria.should_not_receive(:convert_doc_attributes)
      criteria.build_doc(row).should == row
    end
    
    it "assigns the attributes returned from convert_doc_attributes to attributes when record responds to attributes=" do
      atts = { :title => "Hello" }
      row = { "type" => "Offer" }
      criteria.should_receive(:convert_doc_attributes).with(row).and_return atts
      doc = criteria.build_doc(row)
      doc.instance_variable_get("@attributes").should == atts
    end
    
    it "sets the original original_search_doc" do
      original_search_doc = { "type" => "Offer", "id" => "offers/id" }
      criteria.build_doc(original_search_doc).instance_variable_get("@original_search_doc").should == original_search_doc
    end
    
    it "should be readonly" do
      criteria.build_doc(docs.first).should be_readonly
    end
    
    it "should not be a new record" do
      criteria.build_doc(docs.first).should_not be_a_new_record
    end
    
    it "returns an offer and sets all given parameters" do
      criteria.attribute_mapping(:enabled => { :type => :boolean }, :popularity => { :type => :integer })
      doc = criteria.build_doc("type" => "Offer", "id" => "offers/1", "enabled_b" => true, "popularity_i" => 10)
      doc.should be_an_instance_of(Offer)
      doc.popularity.should == 10
    end
    
    it "sets selected parameters even when nil" do
      doc = criteria.select(:enabled, :popularity).build_doc("type" => "Offer", "id" => "offers/1")
      doc.enabled.should be_nil
      doc.popularity.should be_nil
    end
    
    it "it sets parameters to nil when no select given and not present" do
      doc = OfferIndex.search_scope.build_doc("type" => "Offer", "id" => "offers/1")
      doc.should be_an_instance_of(Offer)
      doc.popularity.should be_nil
    end
    
    it "does not set virtual parameters to nil" do
      OfferIndex.search_scope.build_doc("type" => "Offer", "id" => "offers/1").attributes.should_not have_key(:is_deleted)
      OfferIndex.search_scope.build_doc("type" => "Offer", "id" => "offers/1").attributes.should_not have_key("is_deleted")
    end
  end
  
  describe "#select_fields" do
    it "returns the fields from search_options when defined" do
      criteria.select(:enabled).select_fields.should == [:enabled]
    end
    
    it "returns the select_fields from named_search_scope when assigned and responding to" do
      fields = double("fields")
      nsc = double("scope", :select_fields => fields)
      criteria.named_scope_class(nsc)
      criteria.select_fields.should == fields
    end
    
    it "returns an empty array by default" do
      criteria.select_fields.should be_empty
    end
  end
  
  describe "#convert_doc_attributes" do
    { "popularity" => 10, "enabled" => false, "id" => "1" }.each do |key, value|
      it "sets #{key} to #{value}" do
        criteria.convert_doc_attributes("type" => "Offer", "some_other" => "Test", "id" => "offers/1", "enabled" => false, "popularity" => 10)[key].should == value
      end
    end
    
    { "popularity" => 10, "enabled" => true, "id" => "1" }.each do |field, value|
      it "uses sets #{field} to #{value}" do
        criteria.attribute_mapping(:enabled => { :type => :boolean }, :popularity => { :type => :integer })
        criteria.convert_doc_attributes("type" => "Offer", "id" => "offers/1", "enabled_b" => true, "popularity_i" => 10)[field].should == value
      end
    end
  
    
    class MongoOffer
      attr_accessor :id
    end
    
    it "would also work with mongoid ids" do
      criteria.convert_doc_attributes("type" => "MongoOffer", "id" => "offers/4df08c30f3b0a72e7c227a55")["id"].should == "4df08c30f3b0a72e7c227a55"
    end
  end
  
  describe "#reverse_lookup_solr_field" do
    it "returns the key when no mapping found" do
      Supernova::SolrCriteria.new.reverse_lookup_solr_field(:artist_id_s).should == :artist_id_s
    end
    
    it "returns the correct original key when mapped" do
      criteria.attribute_mapping(:artist_name => { :type => :string }).reverse_lookup_solr_field(:artist_name_s).should == :artist_name
    end
  end
  
  describe "#set_first_responding_attribute" do
    it "sets the reverse looked up attribute when found" do
      doc = OpenStruct.new(:artist_name => nil)
      criteria.attribute_mapping(:artist_name => { :type => :string }).set_first_responding_attribute(doc, :artist_name_s, "Mos Def")
      doc.artist_name.should == "Mos Def"
    end
    
    it "sets the original key when no mapping defined" do
      doc = OpenStruct.new(:artist_name_s => nil)
      criteria.attribute_mapping(:artist_name => { :type => :string }).set_first_responding_attribute(doc, :artist_name_s, "Mos Def")
      doc.artist_name_s.should == "Mos Def"
    end
    
    it "does not break on unknown keys" do
      doc = double("dummy")
      criteria.attribute_mapping(:artist_name => { :type => :string }).set_first_responding_attribute(doc, :artist_name_s, "Mos Def")
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
