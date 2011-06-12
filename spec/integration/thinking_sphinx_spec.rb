require 'spec_helper'
require "active_record"
require "thinking_sphinx"
require "mysql2"
require "fileutils"

describe "ThinkingSphinx" do
  let(:ts) { ThinkingSphinx::Configuration.instance }
  
  before(:each) do
    ts.build
    ts.controller.index
    ts.controller.start
    
    
    ThinkingSphinx.deltas_enabled = true
    ThinkingSphinx.updates_enabled = true
    ThinkingSphinx.suppress_delta_output = true
    
    Offer.connection.execute "TRUNCATE offers"
    root = Geokit::LatLng.new(47, 11)
    endpoint = root.endpoint(90, 50, :units => :kms)
    @offer1 = Offer.create!(:id => 1, :user_id => 1, :enabled => false, :text => "Hans Meyer", :popularity => 10, :lat => root.lat, :lng => root.lng)
    @offer2 = Offer.create!(:id => 2, :user_id => 2, :enabled => true, :text => "Marek Mintal", :popularity => 1, :lat => endpoint.lat, :lng => endpoint.lng)
    ts.controller.index
    sleep 0.2
  end
  
  it "finds the correct objects" do
    Offer.for_user_ids(2).to_a.to_a.should == [@offer2]
    Offer.for_user_ids(2, 1).to_a.to_a.sort_by(&:id) == [@offer1, @offer2]
  end
  
  it "correctly filters out unwanted records" do
    Offer.search_scope.without(:user_id => 2).to_a.to_a.sort_by(&:id).should == [@offer1]
    Offer.search_scope.without(:user_id => 1).to_a.to_a.sort_by(&:id).should == [@offer2]
    Offer.search_scope.without(:user_id => 1).without(:user_id => 2).to_a.to_a.sort_by(&:id).should == []
  end
  
  it "returns the corect ids" do
    Offer.for_user_ids(2).ids.to_a.to_a.should == [2]
  end
  
  it "filters by enabled" do
    Offer.search_scope.with(:enabled => true).to_a.to_a.should == [@offer2]
    Offer.search_scope.with(:enabled => false).to_a.to_a.should == [@offer1]
  end
  
  it "combines searches" do
    Offer.search_scope.with(:enabled => false).with(:user_id => 2).to_a.should be_empty
  end
  
  it "searches for names" do
    Offer.search_scope.search("Marek").map(&:id).should == [2]
    Offer.search_scope.search("Hans").map(&:id).should == [1]
  end
  
  it "sorty by popularity" do
    Offer.search_scope.order("popularity desc").map(&:id).should == [1, 2]
  end
  
  describe "geo search" do
    it "finds the correct offers" do
      Offer.search_scope.near(47, 11).within(25.kms).to_a.to_a.should == [@offer1]
    end
    
    it "finds more offers when radius is bigger" do
      Offer.search_scope.near(47, 11).within(49.kms).to_a.should_not include(@offer2)
      Offer.search_scope.near(47, 11).within(51.kms).to_a.should include(@offer2)
    end
    
    it "finds offers around other offers" do
      Offer.search_scope.near(@offer1).within(49.kms).to_a.to_a.should == [@offer1]
      Offer.search_scope.near(@offer1).within(51.kms).order("@geodist desc").to_a.to_a.should == [@offer2, @offer1]
    end
  end
end