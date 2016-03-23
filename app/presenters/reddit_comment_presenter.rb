class RedditCommentPresenter < BasePresenter

  presents :reddit_comment

  def author
    reddit_comment.data.dig("author")
  end

  def content
    if reddit_comment.data.dig("body_html")
      reddit_comment.data.dig("body_html").html_safe
    end
  end

  def author_link
    "https://www.reddit.com/user/#{author}"
  end

end