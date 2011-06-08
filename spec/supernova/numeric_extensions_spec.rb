require 'spec_helper'

describe "NumericExtensions" do
  it "can be called with .meters as well" do
    10.meters.should == 10
    10.0.meters.should == 10
  end
  
  it "converts km to meters" do
    100.0.km.should == 100_000.0
    100.km.should == 100_000.0
    
    100.0.kms.should == 100_000.0
    100.kms.should == 100_000.0
  end
  
  it "converts miles to " do
    100.mile.should == 160_934.72
    100.miles.should == 160_934.72
  end
  
  it "converts deg to radians" do
    90.to_radians.should == Math::PI / 2
  end
  
  it "converts radians to deg" do
    (Math::PI / 2).to_deg.should == 90
  end
end
