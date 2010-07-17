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
    http.stream  {|chunk| handle(chunk) }
    http.errback { @error.call if @error }
  end

  private

  def handle chunk
    return if chunk.chomp.empty?

    hash        = JSON.parse(chunk)
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
