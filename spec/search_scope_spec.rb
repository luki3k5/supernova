require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

class Offer
end

class Host
end

describe "SearchScope" do
  let(:scope) { SearchScope.new }
  
  it "can be initialized" do
    SearchScope.new.should be_an_instance_of(SearchScope)
  end
  
  [
    [:order, "popularity desc"],
    [:group_by, "title"],
    [:search, "query"],
    [:limit, 10],
    [:with, { :stars => 2 }],
    [:conditions, { :stars => 2 }],
    [:paginate, { :stars => 2 }],
    [:select, %w(stars)]
  ].each do |args|
    it "returns the scope itself for #{args.first}" do
      scope.send(*args).should == scope
    end
    
    it "delegates all methods to the instance when responding to" do
      scope_double = SearchScope.new
      SearchScope.should_receive(:new).and_return scope_double
      scope_double.should_receive(args.first).with(*args[1..-1])
      SearchScope.send(*args)
    end
  end
  
  describe "#order" do
    it "sets the order statement" do
      scope.order("popularity desc").options[:order].should == "popularity desc"
    end
  end
  
  describe "#group_by" do
    it "sets the group option" do
      scope.group_by("name").options[:group_by].should == "name"
    end
  end
  
  it "sets the limit option" do
    scope.limit(77).options[:limit].should == 77
  end
  
  describe "#search" do
    it "sets the query" do
      scope.search("title").filters[:query].should == "title"
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
    scope.select(%w(a b)).options[:select].should == %w(a b)
  end
  
  it "sets the correct pagination fields" do
    scope.paginate(:page => 9, :per_page => 2).options[:pagination].should == { :page => 9, :per_page => 2 }
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
end
