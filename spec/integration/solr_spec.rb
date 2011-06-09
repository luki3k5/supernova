require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe "Solr" do
  before(:each) do
    Supernova::Solr.instance_variable_set("@connection", nil)
    Supernova::Solr.url = "http://localhost:8983/solr/"
    Supernova::Solr.truncate!
    Offer.criteria_class = Supernova::SolrCriteria
    root = Geokit::LatLng.new(47, 11)
    endpoint = root.endpoint(90, 50, :units => :kms)
    Supernova::Solr.connection.add(:id => "offers/1", :type => "Offer", :user_id => 1, :enabled => false, :text => "Hans Meyer", :popularity => 10, 
      :location => "#{root.lat},#{root.lng}", :type => "Offer"
    )
    Supernova::Solr.connection.add(:id => "offers/2", :user_id => 2, :enabled => true, :text => "Marek Mintal", :popularity => 1, 
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
  
  describe "searching" do
    it "returns the correct current_page when nil" do
      new_criteria.to_a.current_page.should == 1
    end
    
    it "returns the correct page when set" do
      new_criteria.paginate(:page => 10).to_a.current_page.should == 10
    end
    
    it "the correct per_page when set" do
      new_criteria.paginate(:per_page => 10).to_a.per_page.should == 10
    end
    
    it "the correct per_page when not set" do
      new_criteria.to_a.per_page.should == 25
    end
    
    describe "nearby search" do
      { 49.kms => 1, 51.kms => 2 }.each do |distance, total_entries|
        it "returns #{total_entries} for distance #{distance}" do
          new_criteria.near(47, 11).within(distance).to_a.total_entries.should == total_entries
        end
      end
    end
    
    it "returns the correct objects" do
      new_criteria.with(:user_id => 1).to_a.first.should be_an_instance_of(Offer)
    end
    
    { :id => 1, :user_id => 1, :enabled => false, :text => "Hans Meyer", :popularity => 10 }.each do |key, value|
      it "sets #{key} to #{value}" do
        doc = new_criteria.with(:id => "offers/1").to_a.first
        doc.send(key).should == value
      end
    end
    
    it "combines filters" do
      new_criteria.with(:user_id => 1, :enabled => false).to_a.total_entries.should == 1
      new_criteria.with(:user_id => 1, :enabled => true).to_a.total_entries.should == 0
    end
    
    it "uses the correct orders" do
      new_criteria.order("id desc").to_a.map(&:id).should == [2, 1]
      new_criteria.order("id asc").to_a.map(&:id).should == [1, 2]
    end
    
    it "uses the correct pagination attributes" do
      new_criteria.with(:user_id => 1, :enabled => false).to_a.total_entries.should == 1
      new_criteria.with(:user_id => 1, :enabled => false).length.should == 1
      new_criteria.with(:user_id => 1, :enabled => false).paginate(:page => 10).to_a.total_entries.should == 1
      new_criteria.with(:user_id => 1, :enabled => false).paginate(:page => 10).length.should == 0
      
      new_criteria.paginate(:per_page => 1, :page => 1).to_a.map(&:id).should == [1]
      new_criteria.paginate(:per_page => 1, :page => 2).to_a.map(&:id).should == [2]
    end
    
    it "handels empty results correctly" do
      results = new_criteria.with(:user_id => 1, :enabled => true).to_a
      results.total_entries.should == 0
      results.current_page.should == 1
    end
  end
end