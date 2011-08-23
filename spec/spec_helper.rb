$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'rspec'
require 'supernova'
require "mysql2"
require "logger"
require "fileutils"
require "ruby-debug"
require "geokit"
require "active_record"

def project_root
  Pathname.new(File.expand_path("..", File.dirname(__FILE__)))
end

if defined?(Debugger) && Debugger.respond_to?(:settings)
  Debugger.settings[:autolist] = 1
  Debugger.settings[:autoeval] = true
end

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

RSpec.configure do |config|
  config.before(:each) do
    ActiveRecord::Base.connection.execute("TRUNCATE offers")
  end
end


ActiveRecord::Base.establish_connection(
  :adapter => "mysql2",
  :host => "localhost", 
  :database => "supernova_test", 
  :username => "root",
  :encoding => "utf8"
)


FileUtils.mkdir_p(project_root.join("log"))

ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS offers")
ActiveRecord::Base.connection.execute("CREATE TABLE offers (id SERIAL, text TEXT, user_id INTEGER, enabled BOOLEAN, popularity INTEGER, lat FLOAT, lng FLOAT)")

class Offer < ActiveRecord::Base
  include Supernova::Solr
  named_search_scope :for_user_ids do |*ids|
    with(:user_id => ids.flatten)
  end
end

class Host
  attr_accessor :id
end