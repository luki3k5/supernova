require 'spec_helper'
require "active_record"
require "thinking_sphinx"
require "mysql2"
require "fileutils"

describe "Search" do
  let(:ts) { ThinkingSphinx::Configuration.instance }
  
  before(:each) do
    ts.build
    ts.controller.index
    ts.controller.start
    
    
    ThinkingSphinx.deltas_enabled = true
    ThinkingSphinx.updates_enabled = true
    ThinkingSphinx.suppress_delta_output = true
    
    Offer.connection.execute "TRUNCATE offers"
    @offer1 = Offer.create!(:id => 1, :user_id => 1, :enabled => false, :text => "Hans Meyer", :popularity => 10)
    @offer2 = Offer.create!(:id => 2, :user_id => 2, :enabled => true, :text => "Marek Mintal", :popularity => 1)
    ts.controller.index
    sleep 0.1
  end
  
  it "finds the correct objects" do
    Offer.for_user_ids(2).to_a.to_a.should == [@offer2]
    Offer.for_user_ids(2, 1).to_a.to_a.sort_by(&:id) == [@offer1, @offer2]
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
end