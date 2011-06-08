require 'spec_helper'

describe Supernova::SolrCriteria do
  let(:criteria) { Supernova::SolrCriteria.new }
  let(:rsolr) { double("rsolr").as_null_object }
  
  before(:each) do
    Supernova::Solr.stub!(:connection).and_return rsolr
  end
  
  describe "#to_params" do
    it "returns a Hash" do
      criteria.to_params.should be_an_instance_of(Hash)
    end
    
    it "sets the correct filters" do
      criteria.with(:title => "Hans Maulwurf", :playings => 10).to_params[:fq].should == ["title:Hans Maulwurf", "playings:10"]
    end
    
    it "allways includes some query" do
      criteria.with(:a => 1).to_params[:q].should == "*:*"
    end
    
    it "sets the order field" do
      criteria.order("title").to_params[:sort].should == "title"
    end
    
    it "sets search correct search query" do
      criteria.search("some query").to_params[:q].should == "some query"
    end
    
    it "adds a filter on type when clazz set" do
      Supernova::SolrCriteria.new(Offer).to_params[:fq].should == ["type:#{Offer}"]
    end
    
    it "does not add a filter on type when clazz is nil" do
      criteria.to_params[:fq].should == []
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
    end
    
    it "calls to_params" do
      criteria.should_receive(:to_params).and_return params
      criteria.to_a
    end
    
    # response = Supernova.connection.get("select", :params => to_solr_query)
    it "calls get with select and params" do
      rsolr.should_receive(:get).with("select", :params => params).and_return []
      criteria.to_a
    end
  end
end
