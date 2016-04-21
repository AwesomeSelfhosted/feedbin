class Instaparser
  API_URL = "https://www.instaparser.com/api/1/article".freeze

  def initialize(url)
    @url = url
  end

  def data
    @data ||= begin
      if status == 200
        JSON.parse(request.to_s).tap do |hash|
          hash["host"] = URI.parse(hash["url"]).host
        end
      else
        nil
      end
    end
  end

  def status
    request.code
  end

  private

  def host
    if data
      URI.parse(data["url"]).host
    end
  end

  def request
    @request ||= begin
      HTTP.timeout(:global, write: 5, connect: 5, read: 5).get(API_URL, params: {url: @url, api_key: ENV['INSTAPARSER_API_KEY']})
    end
  end
end