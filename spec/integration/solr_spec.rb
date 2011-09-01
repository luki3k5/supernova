require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe "Solr" do
  before(:each) do
    Supernova::Solr.instance_variable_set("@connection", nil)
    Supernova::Solr.url = "http://localhost:8985/solr/"
    Supernova::Solr.truncate!
    Offer.criteria_class = Supernova::SolrCriteria
    root = Geokit::LatLng.new(47, 11)
    # endpoint = root.endpoint(90, 50, :units => :kms)
    e_lat = 46.9981112912042
    e_lng = 11.6587158814378
    Supernova::Solr.connection.add(:id => "offers/1", :type => "Offer", :user_id_i => 1, :enabled_b => false, 
      :text_t => "Hans Meyer", :popularity_i => 10, 
      :location_p => "#{root.lat},#{root.lng}", :type => "Offer"
    )
    Supernova::Solr.connection.add(:id => "offers/2", :user_id_i => 2, :enabled_b => true, :text_t => "Marek Mintal", 
      :popularity_i => 1, 
      :location_p => "#{e_lat},#{e_lng}", :type => "Offer"
    )
    Supernova::Solr.connection.commit
  end
  
  after(:each) do
    Supernova::Solr.url = nil
    Supernova::Solr.instance_variable_set("@connection", nil)
    Offer.criteria_class = Supernova::SolrCriteria
  end
  
  def new_criteria
    Offer.search_scope
  end
  
  describe "#indexing" do
    before(:each) do
      Supernova::Solr.truncate!
      Supernova::Solr.connection.commit
    end
    
    class OfferIndex < Supernova::SolrIndexer
      has :user_id, :type => :integer
      has :popularity, :type => :integer
      
      def before_index(row)
        row["indexed_at_dt"] = Time.now.utc.iso8601
        row
      end
      
      clazz Offer
    end
    
    it "indexes all Offers without file" do
      offer1 = Offer.create!(:user_id => 1, :popularity => 10)
      offer2 = Offer.create!(:user_id => 2, :popularity => 20)
      indexer = OfferIndex.new(:db => ActiveRecord::Base.connection)
      indexer.index!
      OfferIndex.search_scope.first.instance_variable_get("@original_search_doc")["indexed_at_dt"].should_not be_nil
      OfferIndex.search_scope.total_entries.should == 2
      OfferIndex.search_scope.order("user_id desc").populate.results.should == [offer2, offer1]
      indexer.instance_variable_get("@index_file_path").should be_nil
    end
    
    it "indexes with a file" do
      offer1 = Offer.create!(:user_id => 1, :popularity => 10)
      offer2 = Offer.create!(:user_id => 2, :popularity => 20)
      indexer = OfferIndex.new(:db => ActiveRecord::Base.connection, :max_rows_to_direct_index => 0)
      indexer.index!
      indexer.instance_variable_get("@index_file_path").should_not be_nil
      OfferIndex.search_scope.total_entries.should == 2
      OfferIndex.search_scope.first.instance_variable_get("@original_search_doc")["indexed_at_dt"].should_not be_nil
      OfferIndex.search_scope.order("user_id desc").populate.results.should == [offer2, offer1]
      File.should_not be_exists(indexer.instance_variable_get("@index_file_path"))
    end
    
    it "indexes with a local file" do
      offer1 = Offer.create!(:user_id => 1, :popularity => 10)
      offer2 = Offer.create!(:user_id => 2, :popularity => 20)
      indexer = OfferIndex.new(:db => ActiveRecord::Base.connection, :max_rows_to_direct_index => 0, :local_solr => true)
      indexer.index!
      indexer.instance_variable_get("@index_file_path").should_not be_nil
      OfferIndex.search_scope.first.instance_variable_get("@original_search_doc")["indexed_at_dt"].should_not be_nil
      OfferIndex.search_scope.total_entries.should == 2
      OfferIndex.search_scope.order("user_id desc").populate.results.should == [offer2, offer1]
      File.should_not be_exists(indexer.instance_variable_get("@index_file_path"))
    end
    
    describe "with extra_attributes_from_doc method defined" do
      
      class OfferIndexWitheExtraSearchMethodFromDoc < Supernova::SolrIndexer
        has :user_id, :type => :integer
        has :popularity, :type => :integer
        has :upcased_text, :type => :text, :virtual => true
        has :text, :type => :text
        
        clazz Offer
        
        def extra_attributes_from_record(record)
          { :upcased_text => record.text.to_s.upcase.presence }
        end
      end
      
      it "sets the capitalize_text attribute" do
        Offer.create!(:user_id => 2, :popularity => 20, :text => "lower_text")
        indexer = OfferIndexWitheExtraSearchMethodFromDoc.new(:db => ActiveRecord::Base.connection)
        indexer.index!
        offer = OfferIndexWitheExtraSearchMethodFromDoc.search_scope.first
        offer.instance_variable_get("@original_search_doc")["upcased_text_t"].should == "LOWER_TEXT"
      end
    end
  end
  
  describe "searching" do
    it "returns the correct current_page when nil" do
      new_criteria.current_page.should == 1
    end
    
    it "returns the correct page when set" do
      new_criteria.paginate(:page => 10).current_page.should == 10
    end
    
    it "the correct per_page when set" do
      new_criteria.paginate(:per_page => 10).per_page.should == 10
    end
    
    it "the correct per_page when not set" do
      new_criteria.per_page.should == 25
    end
    
    describe "plain text search" do
      it "returns the correct entries for 1 term" do
        new_criteria.search("text_t:Hans").map { |h| h["id"] }.should == [1]
        new_criteria.search("text_t:Hans").search("text_t:Meyer").map { |h| h["id"] }.should == [1]
        new_criteria.search("text_t:Marek").map { |h| h["id"] }.should == [2]
      end
      
      it "returns the correct options for a combined search" do
        new_criteria.search("text_t:Hans", "text_t:Marek").populate.results.should == []
      end
    end
    
    {
      "id" => "offers/1", "type" => "Offer", "user_id_i" => 1, "enabled_b" => false, "text_t" => "Hans Meyer", 
      "popularity_i" => 10, "location_p" => "47,11"
    }.each do |key, value|
      it "sets #{key} to #{value}" do
        doc = new_criteria.search("text_t:Hans").first.instance_variable_get("@original_search_doc")[key].should == value
      end
    end
    
    describe "nearby search" do
      { 49.kms => 1, 51.kms => 2 }.each do |distance, total_entries|
        it "returns #{total_entries} for distance #{distance}" do
          new_criteria.attribute_mapping(:location => { :type => :location }).near(47, 11).within(distance).total_entries.should == total_entries
        end
      end
    end
    
    describe "range search" do
      { Range.new(2, 3) => [2], Range.new(3, 10) => [], Range.new(1, 2) => [1, 2] }.each do |range, ids|
        it "returns #{ids.inspect} for range #{range.inspect}" do
          new_criteria.with(:user_id_i => range).map { |doc| doc["id"] }.sort.should == ids
        end
      end
    end
    
    describe "not searches" do
      it "finds the correct documents for not nil" do
        Supernova::Solr.connection.add(:id => "offers/3", :enabled_b => true, :text_t => "Marek Mintal", :popularity_i => 1, 
          :type => "Offer"
        )
        Supernova::Solr.connection.commit
        raise "There should be 3 docs" if new_criteria.total_entries != 3
        new_criteria.with(:user_id_i.not => nil).map { |h| h["id"] }.should == [1, 2]
      end
      
      it "finds the correct values for not specific value" do
        new_criteria.with(:user_id_i.not => 1).map { |h| h["id"] }.should == [2]
      end
    end
    
    describe "gt and lt searches" do
      { :gt => [2], :gte => [1, 2], :lt => [], :lte => [1] }.each do |type, ids|
        it "finds ids #{ids.inspect} for #{type}" do
          new_criteria.with(:user_id_i.send(type) => 1).map { |row| row["id"] }.sort.should == ids
        end
      end
    end
    
    it "returns the correct objects" do
      new_criteria.with(:user_id_i => 1).first.should be_an_instance_of(Offer)
    end
    
    { :id => 1, :user_id => 1, :enabled => false, :text => "Hans Meyer", :popularity => 10 }.each do |key, value|
      it "sets #{key} to #{value}" do
        doc = new_criteria.attribute_mapping(
          :user_id => { :type => :integer },
          :enabled => { :type => :boolean },
          :popularity => { :type => :integer },
          :text => { :type => :text}
        ).with(:id => "offers/1").first
        doc.send(key).should == value
      end
    end
    
    it "combines filters" do
      new_criteria.with(:user_id_i => 1, :enabled_b => false).total_entries.should == 1
      new_criteria.with(:user_id_i => 1, :enabled_b => true).total_entries.should == 0
    end
    
    it "uses without correctly" do
      new_criteria.without(:user_id_i => 1).map(&:id).should == [2]
      new_criteria.without(:user_id_i => 2).map(&:id).should == [1]
      new_criteria.without(:user_id_i => 2).without(:user_id_i => 1).map(&:id).should == []
    end
    
    it "uses the correct orders" do
      new_criteria.order("id desc").map(&:id).should == [2, 1]
      new_criteria.order("id asc").map(&:id).should == [1, 2]
    end
    
    it "uses the correct pagination attributes" do
      new_criteria.with(:user_id_i => 1, :enabled_b => false).total_entries.should == 1
      new_criteria.with(:user_id_i => 1, :enabled_b => false).length.should == 1
      new_criteria.with(:user_id_i => 1, :enabled_b => false).paginate(:page => 10).total_entries.should == 1
      new_criteria.with(:user_id_i => 1, :enabled_b => false).paginate(:page => 10).length.should == 0
      
      new_criteria.paginate(:per_page => 1, :page => 1).map(&:id).should == [1]
      new_criteria.paginate(:per_page => 1, :page => 2).map(&:id).should == [2]
    end
    
    it "handels empty results correctly" do
      results = new_criteria.with(:user_id_i => 1, :enabled_b => true)
      results.total_entries.should == 0
      results.current_page.should == 1
    end
    
    it "only sets specific attributes" do
      results = new_criteria.select(:user_id_i).with(:user_id_i => 1)
      results.length.should == 1
      results.first.should == { "id" => "offers/1", "user_id_i" => 1 }
    end
  end
  
  describe "#facets" do
    it "returns the correct facets hash" do
      # pending "fix me"
      Supernova::Solr.connection.add(:id => "offers/3", :type => "Offer", :user_id_i => 3, :enabled_b => false, 
        :text_t => "Hans Müller", :popularity_i => 10, :type => "Offer"
      )
      Supernova::Solr.connection.commit
      new_criteria.facet_fields(:text_t).execute.facets.should == {"text_t"=>{"mintal"=>1, "marek"=>1, "meyer"=>1, "m\303\274ller"=>1, "han"=>2}}
    end
  end
  
  describe "#ids" do
    it "only returns the ids in a collection" do
      result = new_criteria.ids
      result.should be_kind_of(Supernova::Collection)
      result.should == [1, 2]
      result.total_entries.should == 2
    end
  end
  
  describe "with mapping" do
    before(:each) do
      @clazz = Class.new(Supernova::SolrIndexer)
      @clazz.has :location, :type => :string
      @clazz.has :city, :type => :string
    end
    
    it "returns the correct facets" do
      row1 = { "id" => 1, "location" => "Hamburg", "type" => "Offer" }
      row2 = { "id" => 2, "location" => "Hamburg", "type" => "Offer" }
      row3 = { "id" => 3, "location" => "Berlin", "type" => "Offer" }
      @clazz.new.index_rows([row1, row2, row3])
      @clazz.facet_fields(:location).execute.facets.should == { :location=>{ "Berlin"=>1, "Hamburg"=>2 } }
    end
    
    describe "#nin and in" do
      before(:each) do
        row1 = { "id" => 1, "location" => "Hamburg", "type" => "Offer" }
        row2 = { "id" => 2, "location" => "Hamburg", "type" => "Offer" }
        row3 = { "id" => 3, "location" => "Berlin", "type" => "Offer" }
        row4 = { "id" => 4, "location" => "München", "type" => "Offer" }
        Supernova::Solr.truncate!
        Supernova::Solr.connection.commit
        @clazz.new.index_rows([row1, row2, row3, row4])
      end
      
      it "correctly handels nin searches" do
        @clazz.with(:location.in => %w(Hamburg)).execute.map(&:id).should == [1, 2]
        @clazz.with(:location.in => %w(Hamburg Berlin)).execute.map(&:id).should == [1, 2, 3]
      end
      
      it "correctly handels nin queries" do
        @clazz.with(:location.nin => %w(Hamburg)).execute.map(&:id).should == [3, 4]
        @clazz.with(:location.nin => %w(Hamburg Berlin)).execute.map(&:id).should == [4]
      end
    end
  end
end