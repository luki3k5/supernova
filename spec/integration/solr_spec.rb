require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe "Solr" do
  before(:each) do
    Supernova::Solr.instance_variable_set("@connection", nil)
    Supernova::Solr.url = "http://localhost:8983/solr/"
    Supernova::Solr.truncate!
    Offer.criteria_class = Supernova::SolrCriteria
    root = Geokit::LatLng.new(47, 11)
    endpoint = root.endpoint(90, 50, :units => :kms)
    Supernova::Solr.connection.add(:id => 1, :type => "Offer", :user_id => 1, :enabled => false, :text => "Hans Meyer", :popularity => 10, 
      :location => "#{root.lat},#{root.lng}", :type => "Offer"
    )
    Supernova::Solr.connection.add(:id => 2, :user_id => 2, :enabled => true, :text => "Marek Mintal", :popularity => 1, 
      :location => "#{endpoint.lat},#{endpoint.lng}", :type => "Offer"
    )
    Supernova::Solr.connection.commit
  end
  
  after(:each) do
    Supernova::Solr.url = nil
    Supernova::Solr.instance_variable_set("@connection", nil)
    Offer.criteria_class = Supernova::ThinkingSphinxCriteria
  end
  
  def new_criteria
    Offer.search_scope
  end
  
  it "should run" do
    new_criteria.with(:user_id => 1).to_a["response"]["docs"].length.should == 1
    new_criteria.with(:user_id => 1, :enabled => false).to_a["response"]["docs"].length.should == 1
    new_criteria.with(:user_id => 1, :enabled => true).to_a["response"]["docs"].length.should == 0
    new_criteria.with(:user_id => 10).to_a["response"]["docs"].length.should == 0
    new_criteria.near(47, 11).within(49.kms).to_a["response"]["docs"].length.should == 1
    new_criteria.near(47, 11).within(49.kms).with(:enabled => false).to_a["response"]["docs"].length.should == 1
    new_criteria.near(47, 11).within(49.kms).with(:enabled => true).to_a["response"]["docs"].length.should == 0
    new_criteria.near(47, 11).within(51.kms).to_a["response"]["docs"].length.should == 2
  end
end