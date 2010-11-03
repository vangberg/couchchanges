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
  def changes options={}
    EM.run {
      c = CouchChanges.new({:url => URL, :reconnect => 0}.merge(options))
      yield c
      c.listen
    }
  end

  def couch
    @couch ||= CouchRest.new(COUCH)
  end

  def db
    @db ||= couch.database(DATABASE)
  end

  setup do
    db.recreate!
    @doc = {"foo" => "bar"}
    db.save_doc @doc
  end

  test "new document" do
    changes do |c|
      c.change {|c|
        assert_equal @doc["_id"],  c["id"]
        assert_equal @doc["_rev"], c["rev"]
        EM.stop
      }

      c.update {|c|
        assert_equal @doc["_id"],  c["id"]
        assert_equal @doc["_rev"], c["rev"]
        EM.stop
      }

      c.delete {|c| flunk "delete triggered"; EM.stop}
    end
  end

  test "update document" do
    @doc["new_key"] = "new value"
    db.save_doc @doc

    changes do |c|
      c.update {|c|
        assert_equal @doc["_id"],  c["id"]
        assert_equal @doc["_rev"], c["rev"]
        EM.stop
      }

      c.delete {|c| flunk "delete triggered"; EM.stop}
    end
  end

  test "delete document" do
    db.delete_doc @doc

    changes do |c|
      c.delete {|c|
        assert c["deleted"]
        assert_equal @doc["_id"],  c["id"]
        EM.stop
      }

      c.update {|c| flunk "update triggered"; EM.stop}
    end
  end

  test "line spanning multiple chunks (\\n)" do
    EM.run {
      c = CouchChanges.new(:url => URL)

      c.delete {|c|
        assert_equal "doc1", c["id"]
        EM.stop
      }
      
      listener = c.listen

      listener.on_decoded_body_data "{\"seq\":129,\"i"
      listener.on_decoded_body_data "d\":\"doc1\",\"changes\":[{\"rev\":\"6-9ed852183290a143552caf4df76dea87\"}],\"deleted\":true}\n"
    }
  end

  test "multiple changes" do
    doc2, doc3 = {}, {"doc" => 3}
    db.save_doc doc2
    db.save_doc doc3
    db.delete_doc doc3

    count = 0

    changes do |c|
      c.change {|c| count += 1 }
      c.delete {|c|
        assert_equal 3, count
        EM.stop
      }
    end
  end

  test "since" do
    seq = db.info["update_seq"]
    doc2 = {}
    db.save_doc doc2

    changes :since => seq do |c|
      c.change {|c|
        assert c["rev"] > @doc["_rev"], "earlier revision"
        assert_equal doc2["_id"], c["id"]
        EM.stop
      }
    end
  end

  test "include_docs" do
    changes :include_docs => true do |c|
      c.update {|c|
        assert_not_nil c["doc"]
        assert_equal @doc["_id"],  c["doc"]["_id"]
        assert_equal @doc["_rev"], c["doc"]["_rev"]
        assert_equal @doc["foo"],  c["doc"]["foo"]
        EM.stop
      }
    end
  end

  test "filter" do
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

    changes :filter => "app/filtered" do |c|

      c.update {|c|
        assert_equal filtered["_id"], c["id"]
        EM.stop
      }
    end
  end

  test "heartbeat" do
    changes :heartbeat => 100 do |c|
      c.change {|c|
        assert_equal @doc["_id"],  c["id"]
        assert_equal @doc["_rev"], c["rev"]
      }

      EM.add_timer(0.2) { EM.stop }
    end
  end

  test "with disconnect: invoke with last_seq" do
    changes :timeout => 1 do |c|
      c.disconnect {|last_seq|
        assert_equal 1, last_seq
        EM.stop
      }
      EM.add_timer(0.2) { flunk "should invoke disconnect handler" }
    end
  end

  test "without disconnect: default to reconnect" do
    counter = 0

    changes :timeout => 100 do |c|
      c.update {|c|
        counter += 1
        flunk "don't rerun all changes" if counter > 1
      }
      c.delete {|c| EM.stop}

      EM.add_timer(0.2) {
        db.delete_doc @doc
      }
      EM.add_timer(0.5) {
        flunk "didn't reconnect"
      }
    end
  end

  test "don't modify passed in options hash" do
    hash = {:url => "http://127.0.0.1:5984/foo"}
    CouchChanges.new(hash)
    
    assert_equal({:url => "http://127.0.0.1:5984/foo"}, hash)
  end
end
