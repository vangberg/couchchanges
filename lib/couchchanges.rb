require "em-http"
require "uri"
require "json"

class CouchChanges
  def initialize options={}
    @options = options.dup
    @uri = URI.parse(@options.delete(:url) + "/_changes")
    @last_seq = 0
  end

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

  def listen
    @http = http!
    buffer = ""
    @http.stream  {|chunk|
      buffer += chunk
      while line = buffer.slice!(/.+\r?\n/)
        handle line
      end
    }
    @http.errback { disconnected }
    @http
  end

  # REFACTOR!
  def http!
    options = {
      :timeout => 0,
      :query   => @options.merge({:feed => "continuous"})
    }
    if @uri.user
      options[:head] = {'authorization' => [@uri.user, @uri.password]}
    end
    
    EM::HttpRequest.new(@uri.to_s).get(options)
  end

  def handle line
    return if line.chomp.empty?

    hash = JSON.parse(line)
    if hash["last_seq"]
      disconnected
    else
      hash["rev"] = hash.delete("changes")[0]["rev"]
      @last_seq = hash["seq"]

      callbacks hash
    end
  end

  def disconnected
    if @disconnect
      @disconnect.call @last_seq
    else
      @options[:since] = @last_seq
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
