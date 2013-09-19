require "bundler/gem_tasks"

namespace :test do
  desc "Delete test buckets"
  task :delete_buckets do
    require 'riak'
    Riak.disable_list_keys_warnings = true
    client = Riak::Client.new(:host => '127.0.0.1', :protocol => 'pbc')
    bucket_names = [
      'risky_enum',
      'risky_indexes',
      'risky_crud',
      'risky_items',
      'risky_users',
      'risky_mult',
      'risky_concurrent',
      'risky_cron_list',
      'risky_albums',
      'risky_artists',
      'risky_labels',
      'risky_cities',
      'risky_indexes_by_unique',
      'risky_indexes_by_value'
    ]
    bucket_names.each do |bucket_name|
      bucket = client.bucket(bucket_name)
      puts "Deleting keys in #{bucket_name}"
      bucket.keys.map { |k| bucket.delete(k) }
    end
  end
end
