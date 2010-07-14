require "em-http"
require "json"

class CouchChanges
  def change &block
    @change = block
  end

  def create &block
    @create = block
  end

  def update &block
    @update = block
  end

  def delete &block
    @delete = block
  end

  def listen options={}
    http = http(options)
    http.stream {|chunk| handle(chunk)}
  end

  private

  def handle chunk
    return if chunk.chomp.empty?

    hash        = JSON.parse(chunk)
    hash["rev"] = hash.delete("changes")[0]["rev"]
    edit_rev    = hash["rev"].split("-")[0].to_i

    @change.call(hash) if @change

    if hash["deleted"]
      @delete.call(hash) if @delete
    elsif edit_rev == 1
      @create.call(hash) if @create
    elsif edit_rev > 1
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
