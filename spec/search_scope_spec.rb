require 'spec_helper'

describe SearchScope do
  let(:clazz) do
    clazz = Class.new
    clazz.send(:include, SearchScope::ThinkingSphinx)
  end
  
  describe "#including" do
    it "can be includes" do
      Class.new.send(:include, SearchScope::ThinkingSphinx)
    end

    it "defines a search_scope method" do
      clazz.send(:include, SearchScope)
      clazz.should be_respond_to(:search_scope)
    end
  end
  
  describe "#search_scope" do
    before(:each) do
      clazz.search_scope :popular do
        order("popularity desc")
      end
    end
    
    it "defines a new method" do
      clazz.should respond_to(:popular)
    end
    
    it "returns a new criteria" do
      clazz.popular.should be_an_instance_of(SearchScope::ThinkingSphinxCriteria)
    end
    
    it "sets the clazz attribute" do
      clazz.popular.clazz.should == clazz
    end
    
    it "sets the correct order option" do
      clazz.popular.options[:order].should == "popularity desc"
    end
  end
end
