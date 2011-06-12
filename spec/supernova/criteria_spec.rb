require File.expand_path("../spec_helper", File.dirname(__FILE__))
require "ostruct"

describe "Supernova::Criteria" do
  let(:scope) { Supernova::Criteria.new }
  
  
  describe "#initialize" do
    it "can be initialized" do
      Supernova::Criteria.new.should be_an_instance_of(Supernova::Criteria)
    end
    
    it "sets the clazz_name" do
      Supernova::Criteria.new(Offer).clazz.should == Offer
    end
  end
  
  [
    [:order, "popularity desc"],
    [:group_by, "title"],
    [:search, "query"],
    [:limit, 10],
    [:with, { :stars => 2 }],
    [:conditions, { :stars => 2 }],
    [:paginate, { :stars => 2 }],
    [:select, %w(stars)],
    [:near, "test"],
    [:within, 10],
    [:options, {}],
    [:without, {}]
  ].each do |args|
    it "returns the scope itself for #{args.first}" do
      scope.send(*args).should == scope
    end
    
    it "delegates all methods to the instance when responding to" do
      scope_double = Supernova::Criteria.new
      Supernova::Criteria.should_receive(:new).and_return scope_double
      scope_double.should_receive(args.first).with(*args[1..-1])
      Supernova::Criteria.send(*args)
    end
  end
  
  describe "#order" do
    it "sets the order statement" do
      scope.order("popularity desc").search_options[:order].should == "popularity desc"
    end
  end
  
  describe "#group_by" do
    it "sets the group option" do
      scope.group_by("name").search_options[:group_by].should == "name"
    end
  end
  
  it "sets the limit option" do
    scope.limit(77).search_options[:limit].should == 77
  end
  
  describe "#search" do
    it "sets the query" do
      scope.search("title").search_options[:search].should == ["title"]
    end
  end
  
  describe "#for_classes" do
    it "sets the correct classes" do
      scope.for_classes([Offer, Host]).filters[:classes].should == [Offer, Host]
    end
    
    it "also sets single classes" do
      scope.for_classes(Offer).filters[:classes].should == [Offer]
    end
  end
  
  [:with, :conditions].each do |method|
    describe "##{method}" do
      it "adds all filters to the #{method} block" do
        scope.send(method, { :length => 3, :height => 99 }).filters[method].should == { :length => 3, :height => 99 }
      end
    
      it "overwrites before set filters" do
        scope.send(method, { :length => 3, :height => 88 }).send(method, { :length => 4 }).filters[method].should == { :length => 4, :height => 88 }
      end
    end
  end
  
  it "sets select option" do
    scope.select(%w(a b)).search_options[:select].should == %w(a b)
  end
  
  it "sets the correct pagination fields" do
    scope.paginate(:page => 9, :per_page => 2).search_options[:pagination].should == { :page => 9, :per_page => 2 }
  end
  
  describe "#without" do
    it "sets the correct without filter" do
      scope.without(:user_id => 1).filters[:without].should == { :user_id => [1] }
    end
    
    it "combines multiple without filters" do
      scope.without(:user_id => 1).without(:user_id => 1).without(:user_id => 2).filters[:without].should == { :user_id => [1, 2] }
    end
  end
  
  it "to_parameters raises an implement in subclass error" do
    lambda {
      scope.to_parameters
    }.should raise_error("implement in subclass")
  end
  
  it "to_a raises an implement in subclass error" do
    lambda {
      scope.to_a
    }.should raise_error("implement in subclass")
  end
  
  describe "with to_a stubbed" do
    let(:array_double) { double("array") }
    
    before(:each) do
      scope.stub!(:to_a).and_return array_double
    end
    
    [ :first, :each, :count, :last ].each do |method|
      it "forwards #{method} to array" do
        ret = double("ret")
        array_double.should_receive(method).and_return ret
        scope.send(method)
      end
    end
    
    it "hands given blocks in" do
      array = [1, 2, 3]
      scope.stub!(:to_a).and_return array
      called = []
      scope.each do |i|
        called << i
      end
      called.should == array
    end
    
    it "does raise errors when array does not respond" do
      lambda {
        scope.rgne
      }.should raise_error(NoMethodError)
      
    end
  end
  
  describe "#method_missing" do
    it "raises a no method error when methd not defined" do
      lambda {
        scope.method_missing(:rgne)
      }.should raise_error(NoMethodError)
    end
    
    it "calls named_scope_defined" do
      scope.should_receive(:named_scope_defined?).with(:rgne).and_return false
      scope.method_missing(:rgne) rescue nil
    end
    
    it "does not call named scopes when named_scope_defined? returns false" do
      clazz = double("clazz")
      scope = Supernova::Criteria.new(clazz)
      scope.stub(:named_scope_defined?).and_return false
      clazz.should_not_receive(:rgne)
    end
    
    it "it calls merge with self and returned scope" do
      clazz = double("clazz")
      scope = Supernova::Criteria.new(clazz)
      scope.stub(:named_scope_defined?).and_return true
      rge_scope = double("rgne_scope")
      scope_ret = double("ret")
      clazz.should_receive(:rgne).with(1, 2).and_return scope_ret
      merge_ret = double("merge_ret")
      scope.should_receive(:merge).with(scope_ret).and_return merge_ret
      scope.method_missing(:rgne, 1, 2).should == merge_ret
    end
  end
  
  describe "#merge" do
    let(:criteria) { Supernova::Criteria.new.order("popularity asc").with(:a => 1).conditions(:b => 2).search("New Search") }
    let(:new_crit) { Supernova::Criteria.new.order("popularity desc").with(:c => 8).conditions(:e => 9).search("Search") }
    
    it "it returns the original criteria" do
      new_crit.merge(criteria).should == new_crit
    end
    
    it "merges e.g. the order" do
      new_crit.merge(criteria).search_options[:order].should == "popularity asc"
    end
    
    it "merges e.g. the with filters" do
      new_crit.merge(criteria).filters[:with].should == { :c => 8, :a => 1 }
    end
    
    it "merges e.g. the conditions filters" do
      new_crit.merge(criteria).filters[:conditions].should == { :b => 2, :e => 9 }
    end
    
    it "merges search search" do
      new_crit.merge(criteria).search_options[:search].should == ["New Search"]
    end
    
    it "calls merge on options" do
      criteria.stub!(:search_options).and_return({ :x => 2, :y => 9 })
      new_crit.stub!(:search_options).and_return({ :z => 3, :c => 1 })
      new_crit.should_receive(:merge_search_options).with(:x, 2)
      new_crit.should_receive(:merge_search_options).with(:y, 9)
      new_crit.merge(criteria)
    end
    
    it "calls merge filters on all filters" do
      criteria.stub!(:filters).and_return({ :a => 1, :c => 3 })
      new_crit.stub!(:filters).and_return({ :b => 2, :e => 1 })
      new_crit.should_receive(:merge_filters).with(:a, 1)
      new_crit.should_receive(:merge_filters).with(:c, 3)
      new_crit.merge(criteria)
    end
  end
  
  describe "#near" do
    it "sets the geo_center option" do
      scope.near([47, 11]).search_options[:geo_center].should == { :lat => 47.0, :lng => 11.0 }
    end
    
    it "can be called without an array" do
      scope.near(47, 11).search_options[:geo_center].should == { :lat => 47.0, :lng => 11.0 }
    end
  end
  
  describe "#within" do
    it "sets the distance to a value in meters when numeric given" do
      scope.within("test").search_options[:geo_distance].should == "test"
    end
  end
  
  describe "#options" do
    it "merges full hash into options" do
      scope.order("popularity desc").options(:test => "out", :order => "popularity asc").search_options[:custom_options].should == { :test => "out", :order => "popularity asc" }
    end
  end
  
  describe "normalize_coordinates" do
    it "returns a hash when array given" do
      scope.normalize_coordinates([47, 12]).should == { :lat => 47.0, :lng => 12.0 }
    end
    
    it "returns a hash when two parameters given" do
      scope.normalize_coordinates(47, 12).should == { :lat => 47.0, :lng => 12.0 }
    end
    
    [
      [:lat, :lng],
      [:lat, :lon],
      [:latitude, :longitude]
    ].each do |(lat_name, lng_name)|
      it "returns a hash when object responding to lat and lng is given" do
        scope.normalize_coordinates(OpenStruct.new(lat_name => 11, lng_name => 19)).should == { :lat => 11.0, :lng => 19.0 }
      end
    end
  end
  
  describe "#named_scope_defined?" do
    it "returns false when clazz is nil" do
      Supernova::Criteria.new.should_not be_named_scope_defined(:rgne)
    end
    
    it "returns false when clazz is present but not responding to defined_search_scopes" do
      Supernova::Criteria.new("test").should_not be_named_scope_defined(:rgne)
    end
    
    it "returns false when clazz is responding to defined_search_scopes but empty" do
      clazz = Class.new
      class << clazz
        attr_accessor :defined_named_search_scopes
      end
      clazz.defined_named_search_scopes = nil
      Supernova::Criteria.new(clazz).should_not be_named_scope_defined(:rgne)
    end
    
    it "returns false when clazz is responding to defined_search_scopes but not included" do
      clazz = Class.new
      class << clazz
        attr_accessor :defined_named_search_scopes
      end
      clazz.defined_named_search_scopes = [:some_other]
      Supernova::Criteria.new(clazz).should_not be_named_scope_defined(:rgne)
    end
    
    it "returns true when clazz is responding to defined_search_scopes and included" do
      clazz = Class.new
      class << clazz
        attr_accessor :defined_named_search_scopes
      end
      clazz.defined_named_search_scopes = [:rgne]
      Supernova::Criteria.new(clazz).should be_named_scope_defined(:rgne)
    end
  end
end
