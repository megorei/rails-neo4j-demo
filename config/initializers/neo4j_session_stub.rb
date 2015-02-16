if ENV['DISABLE_NEO4J_SESSION']
  class Neo4j::Session
    def self.open(_, _, _); end
  end
end