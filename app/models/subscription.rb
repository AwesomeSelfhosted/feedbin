class Subscription < ApplicationRecord
  attr_accessor :entries_count, :post_volume

  belongs_to :user
  belongs_to :feed, counter_cache: true

  after_commit :mark_as_unread, on: [:create]
  before_destroy :mark_as_read

  before_create :expire_stat_cache
  before_destroy :expire_stat_cache

  after_create :add_feed_to_action
  after_commit :remove_feed_from_action, on: [:destroy]

  before_destroy :untag
  before_destroy :email_unsubscribe

  after_create :refresh_favicon

  def self.create_multiple(feeds, user, valid_feed_ids)
    @subscriptions = feeds.each_with_object([]) do |(feed_id, subscription), array|
      feed = Feed.find(feed_id)
      if valid_feed_ids.include?(feed.id) && subscription["subscribe"] == "1"
        record = user.subscriptions.find_or_create_by(feed: feed)
        record.update(title: subscription["title"].strip)
        array.push(record)
        if subscription["tags"].present?
          feed.tag(subscription["tags"], user, true)
        end
      end
    end
  end

  def mark_as_unread
    base = Entry.select(:id, :feed_id, :published, :created_at).where(feed_id: self.feed_id).order('published DESC')
    entries = base.where('published > ?', Time.now.ago(2.weeks)).limit(10)
    if entries.length == 0
      entries = base.limit(3)
    end
    unread_entries = entries.map do |entry|
      UnreadEntry.new_from_owners(self.user, entry)
    end
    UnreadEntry.import(unread_entries, validate: false)
  end

  def mark_as_read
    UnreadEntry.where(user_id: self.user_id, feed_id: self.feed_id).delete_all
  end

  def add_feed_to_action
    actions = Action.where(user_id: self.user_id, all_feeds: true)
    actions.each do |action|
      action.save
    end
  end

  def remove_feed_from_action
    actions = Action.where(user_id: self.user_id)
    actions.each do |action|
      feed_ids = action.feed_ids || []
      action.feed_ids = feed_ids - [self.feed_id.to_s]
      action.automatic_modification = true
      action.save
    end
  end

  def expire_stat_cache
    Rails.cache.delete("#{self.user_id}:entry_counts")
  end

  def untag
    self.feed.tag('', self.user)
  end

  private

  def email_unsubscribe
    EmailUnsubscribe.perform_async(self.feed_id)
  end

  def refresh_favicon
    FaviconFetcher.perform_async(self.feed.host)
  end

end
