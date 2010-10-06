$:.unshift "lib"

require "test/unit"
require "contest"
require "couchrest"
require "eventmachine"

require "couchchanges"

COUCH    = "http://127.0.0.1:5984"
DATABASE = "couchchanges-test"
URL      = "#{COUCH}/#{DATABASE}"

class TestCouchChanges < Test::Unit::TestCase
  setup do
    db.recreate!
    @changes = CouchChanges.new
    @doc     = {"foo" => "bar"}
    db.save_doc @doc
  end

  def couch
    @couch ||= CouchRest.new(COUCH)
  end

  def db
    @db ||= couch.database(DATABASE)
  end

  def listen! args={}
    args = {:url => URL}.merge(args)
    @changes.listen(args)
  end

  test "new document" do
    EM.run {
      @changes.change {|c|
        assert_equal @doc["_id"],  c["id"]
        assert_equal @doc["_rev"], c["rev"]
        EM.stop
      }

      @changes.update {|c|
        assert_equal @doc["_id"],  c["id"]
        assert_equal @doc["_rev"], c["rev"]
        EM.stop
      }

      @changes.delete {|c| flunk "delete triggered"; EM.stop}

      listen!
    }
  end

  test "update document" do
    EM.run {
      @doc["new_key"] = "new value"
      db.save_doc @doc

      @changes.update {|c|
        assert_equal @doc["_id"],  c["id"]
        assert_equal @doc["_rev"], c["rev"]
        EM.stop
      }

      @changes.delete {|c| flunk "delete triggered"; EM.stop}

      listen!
    }
  end

  test "delete document" do
    EM.run {
      db.delete_doc @doc

      @changes.delete {|c|
        assert c["deleted"]
        assert_equal @doc["_id"],  c["id"]
        EM.stop
      }

      @changes.update {|c| flunk "update triggered"; EM.stop}

      listen!
    }
  end

  test "line spanning multiple chunks (\\n)" do
    EM.run {
      @changes.delete {|c|
        assert_equal "doc1", c["id"]
        EM.stop
      }
      listener = listen!

      listener.http.on_decoded_body_data "{\"seq\":129,\"i"
      listener.http.on_decoded_body_data "d\":\"doc1\",\"changes\":[{\"rev\":\"6-9ed852183290a143552caf4df76dea87\"}],\"deleted\":true}\n"
    }
  end

  #test "multiple changes" do
    #EM.run {
      #doc2, doc3 = {}, {"doc"=>3}
      #db.save_doc doc2
      #db.save_doc doc3
      #db.delete_doc doc3

      #count = 0

      #@changes.change {|c| count += 1 }
      #@changes.delete {|c|
        #assert_equal 3, count
        #EM.stop
      #}

      #listen!
    #}
  #end

  test "listen to multiple feeds" do
    EM.run {
      db2 = couch.database(DATABASE + "2")
      db2.recreate!

      doc2 = {}
      db2.save_doc doc2
      db2.delete_doc doc2

      changed = []

      @changes.change {|c| changed << c["id"]}
      @changes.delete {|c|
        assert_equal 2, changed.size
        assert changed.include?(@doc["_id"]),
          "#{changed} doesn't include #{@doc["_id"]}"
        assert changed.include?(doc2["_id"]),
          "#{changed} doesn't include #{doc2["_id"]}"
        EM.stop
      }

      @changes.listen :url => URL
      @changes.listen :url => (URL + "2")
    }
  end

  test "since" do
    EM.run {
      seq  = db.info["update_seq"]
      doc2 = {}
      db.save_doc doc2

      @changes.change {|c|
        assert c["rev"] > @doc["_rev"], "earlier revision"
        assert_equal doc2["_id"], c["id"]
        EM.stop
      }

      listen! :since => seq
    }
  end

  test "include_docs" do
    EM.run {
      @changes.update {|c|
        assert_not_nil c["doc"]
        assert_equal @doc["_id"],  c["doc"]["_id"]
        assert_equal @doc["_rev"], c["doc"]["_rev"]
        assert_equal @doc["foo"],  c["doc"]["foo"]
        EM.stop
      }

      listen! :include_docs => true
    }
  end

  test "filter" do
    EM.run {
      db.save_doc({
        "_id"     => "_design/app",
        "filters" => {
          "filtered" => "function(doc, req) { return doc.type === 'filtered' }"
        }
      })

      filtered = {"type" => "filtered"}
      other    = {"type" => "other"}
      db.save_doc filtered
      db.save_doc other

      @changes.update {|c|
        assert_equal filtered["_id"], c["id"]
        EM.stop
      }

      listen! :filter => "app/filtered"
    }
  end

  test "heartbeat" do
    EM.run {
      @changes.change {|c|
        assert_equal @doc["_id"],  c["id"]
        assert_equal @doc["_rev"], c["rev"]
      }

      EM.add_timer(0.2) { EM.stop }

      listen! :heartbeat => 100
    }
  end

  test "with disconnect: invoke with last_seq" do
    EM.run {
      @changes.disconnect {|last_seq|
        assert_equal 1, last_seq
        EM.stop
      }
      EM.add_timer(0.2) { flunk "should invoke disconnect handler" }

      listen! :timeout => 1
    }
  end

  #test "without disconnect: default to reconnect" do
    #EM.run {
      #counter = 0
      #@changes.update {|c|
        #counter += 1
        #flunk "don't rerun all changes" if counter > 1
      #}
      #@changes.delete {|c| EM.stop}

      #EM.add_timer(0.2) {
        #db.delete_doc @doc
      #}
      #EM.add_timer(0.5) {
        #flunk "didn't reconnect"
      #}

      #listen! :timeout => 100
    #}
  #end
end
