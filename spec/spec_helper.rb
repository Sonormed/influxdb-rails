$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
ENV['RAILS_ENV'] ||= 'test'

require 'rails'

unless Rails::VERSION::MAJOR > 2
  raise 'Sorry, influxdb-rails only supports Rails 3.x and higher.'
end

require 'bundler/setup'
Bundler.require

require 'fakeweb'
FakeWeb.allow_net_connect = false

if defined? Rails
  puts "Loading Rails v#{Rails.version}..."

  if Rails.version.to_f < 3.0
    raise "Sorry, Rails v#{Rails.version} isn't supported. Try upgrading to Rails 3.x or higher."
  elsif Rails.version.to_f < 4.0
    require 'support/rails3/app'
    require 'rspec/rails'
  else
    require 'support/rails4/app'
    require 'rspec/rails'
  end
end
