class EntryContent
  include Sidekiq::Worker
  sidekiq_options queue: :critical

  S3_POOL = ConnectionPool.new(size: 8, timeout: 5) do
    Fog::Storage.new(
      provider: "AWS",
      aws_access_key_id: ENV["AWS_ENTRIES_ACCESS_KEY_ID"],
      aws_secret_access_key: ENV["AWS_ENTRIES_SECRET_ACCESS_KEY"],
      persistent: true,
      region: ENV["AWS_ENTRIES_REGION"]
    )
  end

  def perform(entry_id)
    @entry = Entry.find(entry_id)
    content = ActiveSupport::Gzip.compress(@entry.content)
    options = {
      'Content-Encoding' => 'gzip'
    }
    S3_POOL.with do |connection|
      connection.put_object(ENV['AWS_ENTRIES_S3_BUCKET'], storage_path, content, options)
    end
    @entry.add_content_info(content_path, @entry.content&.length)
  end

  private

  def content_path
    @content_path ||= "#{@entry.public_id[0..4]}/#{@entry.public_id}-#{SecureRandom.hex}"
  end

end
