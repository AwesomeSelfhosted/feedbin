class DevicePushNotificationSend
  include Sidekiq::Worker
  sidekiq_options retry: false, queue: :critical

  APNOTIC_POOL = Apnotic::ConnectionPool.new({cert_path: ENV['APPLE_PUSH_CERT_IOS']}, size: 5)

  def perform(user_ids, entry_id)
    Honeybadger.context(user_ids: user_ids, entry_id: entry_id)
    tokens = Device.where(user_id: user_ids).ios.pluck(:user_id, :token, :operating_system)
    entry = Entry.find(entry_id)
    feed = entry.feed

    feed_titles = subscription_titles(user_ids, feed)
    feed_title = format_text(feed.title)

    notifications = tokens.each_with_object({}) do |(user_id, token, operating_system), hash|
      feed_title = feed_titles[user_id] || feed_title
      notification = build_notification(token, feed_title, entry, operating_system)
      hash[notification.apns_id] = notification
    end

    APNOTIC_POOL.with do |connection|
      notifications.each do |_, notification|
        push = connection.prepare_push(notification)
        push.on(:response) do |response|
          Librato.increment('apns.ios.sent', source: response.status)
          if response.status == '410' || (response.status == '400' && response.body['reason'] == 'BadDeviceToken')
            apns_id = response.headers["apns-id"]
            token = notifications[apns_id].token
            Device.where("lower(token) = ?", token.downcase).take&.destroy
          end
        end
        connection.push_async(push)
      end
      connection.join
    end

  end

  private

  def subscription_titles(user_ids, feed)
    titles = Subscription.where(feed: feed, user_id: user_ids).pluck(:user_id, :title)
    titles.each_with_object({}) do |(user_id, feed_title), hash|
      title = format_text(feed_title)
      hash[user_id] = (title.present?) ? title : nil
    end
  end

  def format_text(text)
    text ||= ""
    decoder = HTMLEntities.new
    text = ActionController::Base.helpers.strip_tags(text)
    text = text.gsub("\n", "")
    text = text.gsub(/\t/, "")
    text = decoder.decode(text)
    text
  end

  def build_notification(device_token, feed_title, entry, operating_system)
    body = format_text(entry.title)
    if body.empty?
      body = format_text(entry.summary)
    end
    author = format_text(entry.author)
    title = format_text(entry.title)
    published = entry.published.iso8601(6)
    unless operating_system =~ /^iPhone OS 10/
      body = "#{feed_title}: #{body}"
    end
    Apnotic::Notification.new(device_token).tap do |notification|
      notification.alert = {
        title: feed_title,
        body: body,
      }
      notification.custom_payload = {
        feedbin: {
          entry_id: entry.id,
          title: title,
          feed: feed_title,
          author: author,
          published: published
        }
      }
      notification.category = "singleArticle"
      notification.content_available = true
      notification.sound = ""
      notification.priority = "10"
      notification.topic = ENV['APPLE_PUSH_TOPIC']
      notification.apns_id = SecureRandom.uuid
    end
  end

end
