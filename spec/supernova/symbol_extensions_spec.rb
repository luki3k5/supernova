require 'spec_helper'

describe "Supernova::SymbolExtensions" do
  [:not, :gt, :lt, :gte, :lte, :ne].each do |type|
    it "returns the correct condition for #{type}" do
      cond = :user_id.send(type)
      cond.key.should == :user_id
      cond.type.should == type
    end
  end
  
  it "sets the correct key" do
    :other_id.not.key.should == :other_id
  end
end
