$:.unshift "lib"

require "test/unit"
require "contest"
require "couchrest"
require "eventmachine"

require "couchchanges"

COUCH    = "http://127.0.0.1:5984"
DATABASE = "couchchanges-test"
URL      = "#{COUCH}/#{DATABASE}"

class Test::Unit::TestCase
  def couch
    @couch ||= CouchRest.new(COUCH)
  end

  def db
    @db ||= couch.database(DATABASE)
  end

  setup do
    db.recreate!
  end
end
