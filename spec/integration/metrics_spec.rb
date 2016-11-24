require File.expand_path(File.dirname(__FILE__) + '/integration_helper')

describe 'collecting metrics through ActiveSupport::Notifications', type: :request do
  before do
    InfluxDB::Rails.configure do |config|
      config.ignored_environments = %w(development)
      config.instrumentation_enabled = true
    end
  end

  describe 'in a normal request' do
    it 'should attempt to handle ActionController metrics' do
      expect(InfluxDB::Rails).to receive(:handle_action_controller_metrics).once
      get '/widgets'
    end

    it 'should result in attempts to write metrics via the client' do
      expect(InfluxDB::Rails.client).to receive(:write_point).exactly(3).times
      get '/widgets'
    end
  end
end
