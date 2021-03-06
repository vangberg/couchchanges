$:.unshift "lib"
require "eventmachine"
require "couchchanges"

EventMachine.run {
  couch = CouchChanges.new :url => "http://127.0.0.1:5984/couchchanges"

  couch.change {|change|
    puts "doc created, updated or deleted"
  }
  couch.update {|change|
    puts "doc created or updated"
  }
  couch.delete {|change|
    puts "doc deleted"
  }
  couch.listen
}
