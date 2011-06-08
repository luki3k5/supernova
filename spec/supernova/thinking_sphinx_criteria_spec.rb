require 'spec_helper'

describe "Supernova::ThinkingSphinxCriteria" do
  let(:scope) { Supernova::ThinkingSphinxCriteria.new }
  
  describe "#to_params" do
    it "returns an array" do
      scope.to_params.should be_an_instance_of(Array)
    end
    
    it "sets the correct order query" do
      scope.order("title desc").to_params.at(1)[:order].should == "title desc"
    end
    
    it "sets the correct group_by statement" do
      scope.group_by("title").to_params.at(1)[:group_by].should == "title"
    end
    
    it "sets the match_mode to boolean" do
      scope.to_params.at(1)[:match_mode].should == :boolean
    end
    
    it "does not set the classes field by default" do
      scope.to_params.at(1).should_not have_key(:classes)
    end
    
    it "sets the classes field when classes set" do
      scope.for_classes(Offer).to_params.at(1)[:classes].should == [Offer]
    end
    
    it "sets the search query when present" do
      scope.search("some test").to_params.at(0).should == "some test"
    end
    
    it "sets a set limit" do
      scope.limit(88).to_params.at(1)[:limit].should == 88
    end
    
    it "calls sphinx with select fields" do
      scope.select(%w(id title name)).to_params.at(1)[:select].should == %w(id title name)
    end
    
    it "sets the correct with filters" do
      scope.with(:a => 1).with(:b => 2).to_params.at(1)[:with].should == {
        :a => 1,
        :b => 2
      }
    end
    
    it "sets the correct geo option filter" do
      scope.near(53.5748, 10.0347).within(5.kms).to_params.at(1)[:geo].map(&:to_s).should == ["0.935056656097458", "0.175138554449875"]
    end
    
    it "merges correct with options" do
      scope.near(53.5748, 10.0347).within(5.kms).with(:filter => true).to_params.at(1)[:with].should == {
        "@geodist" => 5_000.0,
        :filter => true
      }
    end
    
    it "sets the correct geo distance filter" do
      # @geodist
      scope.near(53.5748, 10.0347).within(7.kms).to_params.at(1)[:with]["@geodist"].should == 7_000.0
    end
    
    { :page => 8, :per_page => 1 }.each do |key, value|
      it "sets pagination pagination #{key} to #{value}" do
        scope.paginate(key => value).to_params.at(1)[key].should == value
      end
    end
  end
  
  describe "with to_params mockes" do
    let(:query) { double("query") }
    let(:options) { double("options") }
    let(:sphinx_response) { double("sphinx_respons") }
    
    before(:each) do
      scope.stub!(:to_params).and_return([query, options])
    end
    
    describe "#to_a" do
      it "returns the sphinx search" do
        ThinkingSphinx.stub!(:search).and_return sphinx_response
        scope.to_a.should == sphinx_response
      end

      it "calls ThinkingSphinx with what to_params returns" do
        ThinkingSphinx.should_receive(:search).with(query, options).and_return sphinx_response
        scope.to_a.should == sphinx_response
      end
    end

    it "forwards ids to search_for_ids" do
      ids_response = double("id response")
      ThinkingSphinx.should_receive(:search_for_ids).with(query, options).and_return ids_response
      scope.ids
    end
    
    it "forwards total_entries to search_for_ids" do
      ids_response = double("id response")
      ThinkingSphinx.should_receive(:search_for_ids).with(query, options).and_return ids_response
      ids_response.should_receive(:total_entries).and_return 88
      scope.total_entries.should == 88
    end
  end
end
