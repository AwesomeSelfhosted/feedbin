class RedditLinkPresenter < BasePresenter

  presents :reddit_link

  def content
    if embed = reddit_link.data.dig("secure_media", "oembed", "html")
      embed.html_safe
    elsif reddit_link.data.dig("selftext_html")
      reddit_link.data.dig("selftext_html").html_safe
    elsif reddit_link.data.dig("url") =~ /\.(jpg|jpeg|gif|png)$/i
      @template.image_tag(reddit_link.data.dig("url")).html_safe
    elsif reddit_link.data.dig("url") =~ /\.(gifv)$/i
      @template.image_tag(reddit_link.data.dig("url").sub("gifv", "gif")).html_safe
    elsif reddit_link.data.dig("url") =~ /^https?:\/\/imgur\.com\/(.*?)$/i && $1
      @template.image_tag("https://i.imgur.com/#{$1}.jpg").html_safe
    end
  end

end