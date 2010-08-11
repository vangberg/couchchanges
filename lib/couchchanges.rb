require "em-http"
require "json"

class CouchChanges
  class ConnectionError < StandardError; end

  def change &block
    @change = block
  end

  def update &block
    @update = block
  end

  def delete &block
    @delete = block
  end

  def error &block
    @error = block
  end

  def listen options={}
    http = http(options)
    buffer = ""
    http.stream  {|chunk|
      buffer += chunk
      while line = buffer.slice!(/.+\r?\n/)
        handle line
      end
    }
    http.errback { @error.call if @error }
    http
  end

  private

  def handle line
    return if line.chomp.empty?

    hash        = JSON.parse(line)
    hash["rev"] = hash.delete("changes")[0]["rev"]

    @change.call(hash) if @change

    if hash["deleted"]
      @delete.call(hash) if @delete
    else
      @update.call(hash) if @update
    end
  end

  def http options
    url = options.delete(:url) + "/_changes"
    EM::HttpRequest.new(url).get(
      :timeout => 0,
      :query   => options.merge({:feed => "continuous"})
    )
  end
end
