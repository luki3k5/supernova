require 'spec_helper'

describe Supernova do
  let(:clazz) do
    clazz = Class.new
    clazz.send(:include, Supernova::ThinkingSphinx)
  end
  
  describe "#including" do
    it "can be includes" do
      Class.new.send(:include, Supernova::ThinkingSphinx)
    end

    it "defines a named_search_scope method" do
      clazz.send(:include, Supernova)
      clazz.should be_respond_to(:named_search_scope)
    end
  end
  
  describe "#search_scope" do
    it "returns a new criteria" do
      clazz.search_scope.should be_an_instance_of(Supernova::ThinkingSphinxCriteria)
    end
    
    it "sets the correct clazz" do
      clazz.search_scope.clazz.should == clazz
    end
  end
  
  describe "#named_search_scope" do
    before(:each) do
      clazz.named_search_scope :popular do
        order("popularity desc")
      end
    end
    
    describe "without parameters" do
      it "defines a new method" do
        clazz.should respond_to(:popular)
      end

      it "returns a new criteria" do
        clazz.popular.should be_an_instance_of(Supernova::ThinkingSphinxCriteria)
      end

      it "sets the clazz attribute" do
        clazz.popular.clazz.should == clazz
      end

      it "sets the correct order option" do
        clazz.popular.search_options[:order].should == "popularity desc"
      end
      
      it "adds the name of the scope to the defined_named_search_scopes array" do
        clazz.defined_named_search_scopes.should == [:popular]
      end
    end
    
    describe "chaining" do
      it "calls merge with both scopes" do
        scope = Supernova::ThinkingSphinxCriteria.new(clazz)
        scope.should_receive(:merge).with(instance_of(Supernova::ThinkingSphinxCriteria))
        scope.popular
      end
      # Supernova::ThinkingSphinxCriteria.new(clazz).popular.should be_an_instance_of()
    end
    
    describe "with parameters" do
      before(:each) do
        clazz.named_search_scope :for_artists do |artist_ids|
          with(:artist_id => artist_ids)
        end
        clazz.named_search_scope :popular do
          order("popularity desc")
        end
      end
      
      it "sets the correct filters" do
        clazz.for_artists(%w(1 3 2)).filters[:with][:artist_id].should == %w(1 3 2)
      end
      
      it "allows chaining of named_search_scopes" do
        clazz.for_artists(%w(1 3 2)).popular.search_options[:order].should == "popularity desc"
      end
    end
  end
end
