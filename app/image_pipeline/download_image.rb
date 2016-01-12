require 'rmagick'
require 'opencv'

class DownloadImage

  attr_reader :image, :url

  def initialize(url)
    @url = url
    @image = nil
  end

  def download
    success = false
    if @image = get_image
      success = @image.process
    end
    success
  end

  def get_image
    image = nil
    options = {use_ssl: @url.scheme == "https", open_timeout: 5, read_timeout: 30}
    Net::HTTP.start(@url.host, @url.port, options) do |http|
      http.request_get(@url.request_uri) do |response|
        image = download_image(response) if headers_valid?(response.to_hash)
      end
    end
    image
  end

  def download_image(response)
    file = Tempfile.new(["original-", ".jpg"])
    file.binmode
    response.read_body do |chunk|
      file.write(chunk)
    end
    file.rewind
    file.close
    ProcessedImage.new(file)
  rescue Exception => e
    file && file.close(true)
    raise e
  end

  def headers_valid?(headers)
    headers["content-type"].first == "image/jpeg" && headers["content-length"].first.to_i > 20_000
  rescue
    false
  end

  def to_h
    {
      original: {
        url: self.url.to_s,
        width: self.image.original_width.to_i,
        height: self.image.original_height.to_i,
      },
      cropped_1: {
        url: self.image.url.to_s,
        width: self.image.width.to_i,
        height: self.image.height.to_i,
      }
    }
  end

end