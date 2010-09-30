require "em-http"
require "json"

class CouchChanges
  class ConnectionError < StandardError; end

  def change &block
    block ? @change = block : @change
  end

  def update &block
    block ? @update = block : @update
  end

  def delete &block
    block ? @delete = block : @delete
  end

  def listen options={}
    listener = Listener.new(self, options)
    listener.start
    listener
  end

  class Listener
    def initialize changes, options
      @changes = changes
      @url     = options.delete(:url)
      @options = options
    end

    attr_reader :http

    def start
      @http = http!
      buffer = ""
      @http.stream  {|chunk|
        buffer += chunk
        while line = buffer.slice!(/.+\r?\n/)
          handle line
        end
      }
      @http
    end

    def handle line
      return if line.chomp.empty?

      hash = JSON.parse(line)
      if hash["last_seq"]
        start
      else
        hash["rev"] = hash.delete("changes")[0]["rev"]

        @changes.change.call(hash) if @changes.change

        if hash["deleted"]
          @changes.delete.call(hash) if @changes.delete
        else
          @changes.update.call(hash) if @changes.update
        end
      end
    end

    def http!
      url = @url + "/_changes"
      EM::HttpRequest.new(url).get(
        :timeout => 0,
        :query   => @options.merge({:feed => "continuous"})
      )
    end
  end
end
