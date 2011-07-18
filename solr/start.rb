root = File.expand_path("..", __FILE__)
cmd = "cd /usr/local/Cellar/solr/3.1.0/libexec/example/ && java -Dsolr.data.dir=#{root}/data -Dsolr.solr.home=#{root} -Djetty.port=8985 -jar start.jar > #{File.expand_path("../log/solr.log", root)} 2>&1 &"
system(cmd)