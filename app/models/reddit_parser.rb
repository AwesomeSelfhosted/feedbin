class RedditParser

  def initialize(url)
    @url = "#{url}.json?raw_json=1"
  end

  def data
    @data ||= Rails.cache.fetch("url_cache:#{Digest::SHA1.hexdigest(@url)}", expires_in: 1.hour) do
      response = HTTParty.get(@url, headers: {"User-Agent" => "Feedbin (https://feedbin.com)"})
      JSON.load(response.body)
    end
  end

  def content
    @content ||= Rails.cache.fetch("reddit_cache:#{Digest::SHA1.hexdigest(@url)}", expires_in: 1.hour) do
      action_view = ActionView::Base.new()
      action_view.view_paths = ActionController::Base.view_paths
      action_view.extend(ApplicationHelper)
      action_view.render(template: "entries/reddit/inline.html.erb", locals: {data: data})
    end
  end

end