$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'rspec'
require 'supernova'
require "mysql2"
require "logger"

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

RSpec.configure do |config|
  
end

ActiveRecord::Base.establish_connection(
  :adapter => "mysql2",
  :host => "localhost", 
  :database => "supernova_test", 
  :username => "root",
  :encoding => "utf8"
)

ThinkingSphinx::ActiveRecord::LogSubscriber.logger = Logger.new(
  open(File.expand_path("../log/active_record.log", File.dirname(__FILE__)), "a")
)

ActiveRecord::Base.send(:include, ThinkingSphinx::ActiveRecord)

ActiveRecord::Base.connection.execute("DROP TABLE offers")
ActiveRecord::Base.connection.execute("CREATE TABLE offers (id SERIAL, text TEXT, user_id INTEGER, enabled BOOLEAN, popularity INTEGER, lat FLOAT, lng FLOAT)")

class Offer < ActiveRecord::Base
  include Supernova::ThinkingSphinx
  
  define_index do
    indexes text
    has :user_id
    has :enabled
    has :popularity, :sort => true
    
    has "RADIANS(lat)",  :as => :latitude,  :type => :float
    has "RADIANS(lng)", :as => :longitude, :type => :float
  end
  
  named_search_scope :for_user_ids do |*ids|
    with(:user_id => ids.flatten)
  end
end

class Host
end