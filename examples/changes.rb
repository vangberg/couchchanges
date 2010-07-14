$:.unshift "lib"
require "eventmachine"
require "couchchanges"

EventMachine.run {
  couch = CouchChanges.new

  couch.change {|change|
    puts "doc created, updated or deleted"
  }
  couch.create {|change|
    puts "doc created"
  }
  couch.update {|change|
    puts "doc updated"
  }
  couch.delete {|change|
    puts "doc deleted"
  }

  couch.listen :url => "http://127.0.0.1:5984/memolane"
}
