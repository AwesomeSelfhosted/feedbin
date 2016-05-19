$entry_storage = ConnectionPool.new(size: 8, timeout: 5) do
  Fog::Storage.new(
    provider: "AWS",
    aws_access_key_id: ENV["AWS_ENTRIES_ACCESS_KEY_ID"],
    aws_secret_access_key: ENV["AWS_ENTRIES_SECRET_ACCESS_KEY"],
    persistent: true,
    region: "us-west-1",
  )
end
$entry_data = ConnectionPool.new(size: 8, timeout: 5) do
  HTTP.persistent "https://d2do1hj4m58fgz.cloudfront.net"
end