require_relative '../../lib/batch_jobs'

class FeedRefresher
  include BatchJobs
  include Sidekiq::Worker

  def perform(batch, count)
    @count = count
    feed_ids = build_ids(batch)
    jobs = build_arguments(feed_ids, count)
    if jobs.present?
      Sidekiq::Client.push_bulk(
        'args'  => jobs,
        'class' => 'FeedRefresherFetcher',
        'queue' => 'feed_refresher_fetcher',
        'retry' => false
      )
    end
  end

  def _debug(feed_id)
    @count = 0
    Sidekiq::Client.push_bulk(
      'args'  => build_arguments([feed_id]),
      'class' => 'FeedRefresherFetcher',
      'queue' => 'feed_refresher_fetcher_debug',
      'retry' => false
    )
  end

  private

  def build_arguments(feed_ids)
    fields = [:id, :feed_url, :etag, :last_modified, :subscriptions_count, :push_expiration]
    subscriptions = Subscription.where(feed_id: feed_ids, active: true, muted: false).group(:feed_id).count
    feeds = Feed.xml.where(id: feed_ids, active: true).where("subscriptions_count > ?", subscriptions_count).pluck(*fields)
    feeds.each_with_object([]) do |result, array|
      feed = Hash[fields.zip(result)]
      if subscriptions.has_key?(feed[:id])
        array << Arguments.new(feed, url_template, force_refresh?).to_a
      end
    end
  end

  def subscriptions_count
    (priority?) ? 1 : 0
  end

  def priority?
    @priority ||= @count % 2 == 0
  end

  def force_refresh?
    @force_refresh ||= @count % 2 != 0 && @count % 3 == 0
  end

  def url_template
    @url_template ||= begin
      template = nil
      if ENV['PUSH_URL']
        uri = URI(ENV['PUSH_URL'])
        id = 454545
        template = Rails.application.routes.url_helpers.push_feed_url(Feed.new(id: id), protocol: uri.scheme, host: uri.host)
        template = template.sub(id.to_s, "%d")
      end
      template
    end
  end

  class Arguments
    def initialize(feed, push_url, force_refresh = false)
      @feed = feed
      @push_url = push_url
      @force_refresh = force_refresh
    end

    def to_a
      options = {
        etag: etag,
        last_modified: last_modified,
        subscriptions_count: @feed[:subscriptions_count],
        push_callback: push_callback,
        hub_secret: hub_secret,
        push_mode: push_mode
      }
      [@feed[:id], @feed[:feed_url], options]
    end

    private

    def etag
      @force_refresh ? nil : @feed[:etag]
    end

    def last_modified
      @force_refresh ? nil : @feed[:last_modified]
    end

    def push_callback
      (push?) ? @push_url % @feed[:id] : nil
    end

    def hub_secret
      (push?) ? Push::hub_secret(@feed[:id]) : nil
    end

    def push_mode
      (push?) ? "subscribe" : nil
    end

    def push?
      @push ||= @push_url && @feed[:push_expiration].nil? || @feed[:push_expiration] < Time.now
    end

  end

end