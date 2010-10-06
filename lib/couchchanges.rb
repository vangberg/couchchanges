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

  def disconnect &block
    block ? @disconnect = block : @disconnect
  end

  def listen options={}
    listener = Listener.new(self, options)
    listener.start
    listener
  end

  class Listener
    def initialize changes, options
      @changes  = changes
      @url      = options.delete(:url)
      @options  = options
      @last_seq = 0
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

    def reconnect_since last_seq
      @options[:since] = last_seq
      start
    end

    def handle line
      return if line.chomp.empty?

      hash = JSON.parse(line)
      if hash["last_seq"]
        @changes.disconnect.call hash["last_seq"]
        #reconnect_since hash["last_seq"]
      else
        hash["rev"] = hash.delete("changes")[0]["rev"]
        callbacks hash
      end
    end

    def callbacks hash
      @changes.change.call hash if @changes.change
      if hash["deleted"]
        @changes.delete.call hash if @changes.delete
      else
        @changes.update.call hash if @changes.update
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
