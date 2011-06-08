require 'spec_helper'

describe Supernova::Solr do
  let(:rsolr) { double("rsolr") }
  
  before(:each) do
    RSolr.stub!(:connect).and_return rsolr
  end
  
  describe "#url=" do
    it "allows setting a solr url" do
      Supernova::Solr.url = "some url"
      Supernova::Solr.url.should == "some url"
    end
  end
  
  describe "#solr_connection" do
    after(:each) do
      Supernova::Solr.url = nil
    end
    
    before(:each) do
      Supernova::Solr.url = "/some/url"
    end
    
    it "connects creates and stores a new RSolr connection" do
      RSolr.should_receive(:connect).with(:url => "/some/url").and_return rsolr
      Supernova::Solr.connection.should == rsolr
      Supernova::Solr.instance_variable_get("@connection").should == rsolr
    end
    
    it "returns a stored connection" do
      con = double("con")
      Supernova::Solr.instance_variable_set("@connection", con)
      Supernova::Solr.connection.should == con
    end
  end
end
