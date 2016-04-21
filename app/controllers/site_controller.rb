class SiteController < ApplicationController

  skip_before_action :authorize, only: [:index, :parser]
  before_action :check_user, if: :signed_in?

  def index
    if signed_in?
      get_feeds_list
      subscriptions = @user.subscriptions

      user_titles = subscriptions.each_with_object({}) do |subscription, hash|
        if subscription.title.present?
          hash[subscription.feed_id] = ERB::Util.html_escape_once(subscription.title)
        end
      end

      readability_settings = subscriptions.each_with_object({}) do |subscription, hash|
        hash[subscription.feed_id] = subscription.view_inline
      end

      @show_welcome = (subscriptions.present?) ? false : true
      @classes = user_classes
      @data = {
        login_url: login_url,
        tags_path: tags_path(format: :json),
        user_titles: user_titles,
        preload_entries_path: preload_entries_path(format: :json),
        sticky_readability: @user.setting_on?(:sticky_view_inline),
        readability_settings: readability_settings,
        show_unread_count: @user.setting_on?(:show_unread_count),
        precache_images: @user.setting_on?(:precache_images),
        auto_update_path: auto_update_feeds_path,
        font_sizes: Feedbin::Application.config.font_sizes,
        mark_as_read_path: mark_all_as_read_entries_path,
        mark_as_read_confirmation: @user.setting_on?(:mark_as_read_confirmation),
        mark_direction_as_read_entries: mark_direction_as_read_entries_path,
        entry_sort: @user.entry_sort,
        update_message_seen: @user.setting_on?(:update_message_seen),
        feed_order: @user.feed_order,
        refresh_sessions_path: refresh_sessions_path
      }

      render action: 'logged_in'
    else
      render_file_or("home/index.html", :ok) {
        redirect_to login_url
      }
    end
  end

  private

  def parser
    id = $redis.incr("rtest5")

    entry = Entry.find(id)
    @url = entry.fully_qualified_url

    instaparser = Rails.cache.fetch("instaparser:#{Digest::SHA1.hexdigest(@url)}") do
      Instaparser.new(@url).data
    end
    @instaparser = instaparser["html"]

    readability = Rails.cache.fetch("readability:#{Digest::SHA1.hexdigest(@url)}") do
      ReadabilityParser.parse(@url)
    end
    @readability = readability.content
  end

  def check_user
    if current_user.suspended
      redirect_to settings_billing_url, alert: 'Please update your billing information to use Feedbin.'
    end
  end

end
