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

  def initialize options={}
    @url = options.delete(:url)
    @options = options
  end

  def listen
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

  def http!
    url = @url + "/_changes"
    EM::HttpRequest.new(url).get(
      :timeout => 0,
      :query   => @options.merge({:feed => "continuous"})
    )
  end

  def handle line
    return if line.chomp.empty?

    hash = JSON.parse(line)
    if hash["last_seq"]
      disconnected hash["last_seq"]
    else
      hash["rev"] = hash.delete("changes")[0]["rev"]
      callbacks hash
    end
  end

  def disconnected last_seq
    if @disconnect
      @disconnect.call last_seq
    else
      @options[:since] = last_seq
      listen
    end
  end

  def callbacks hash
    @change.call hash if @change
    if hash["deleted"]
      @delete.call hash if @delete
    else
      @update.call hash if @update
    end
  end
end
