# couchchanges

a ruby consumer for couchdb's _changes feed. eventmachine based.

## example.rb

    require "eventmachine"
    require "couchchanges"

    EventMachine.run {
      couch = CouchChanges.new :url => "http://127.0.0.1:5984/my_db"

      couch.change {|change|
        puts "doc created, updated or deleted"
      }
      couch.update {|change|
        puts "doc created or updated"
      }
      couch.delete {|change|
        puts "doc deleted"
      }

      # if you don't specify a disconnect block, couchchanges will
      # automatically reconnect to couchdb. normally you shouldn't
      # care about the disconnect callback, but it can come in
      # handy in tests etc.
      couch.disconnect {|last_seq|
        puts "disconnected from couch. last_seq: #{last_seq}"
      }
    }
