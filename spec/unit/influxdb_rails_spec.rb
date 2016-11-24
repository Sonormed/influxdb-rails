require 'spec_helper'

describe InfluxDB::Rails do
  before do
    InfluxDB::Rails.configure { |config| config.ignored_environments = [] }
  end

  describe '.ignorable_exception?' do
    it 'should be true for exception types specified in the configuration' do
      class DummyException < RuntimeError; end
      exception = DummyException.new

      InfluxDB::Rails.configure do |config|
        config.ignored_exceptions << 'DummyException'
      end

      expect(InfluxDB::Rails.ignorable_exception?(exception)).to be_truthy
    end

    it 'should be true for exception types specified in the configuration' do
      exception = ActionController::RoutingError.new('foo')
      expect(InfluxDB::Rails.ignorable_exception?(exception)).to be_truthy
    end

    it 'should be false for valid exceptions' do
      exception = ZeroDivisionError.new
      expect(InfluxDB::Rails.ignorable_exception?(exception)).to be_falsey
    end
  end

  describe 'rescue' do
    it 'should transmit an exception when passed' do
      InfluxDB::Rails.configure do |config|
        config.ignored_environments = []
        config.instrumentation_enabled = false
      end

      expect(InfluxDB::Rails.client).to receive(:write_point)

      InfluxDB::Rails.rescue do
        raise ArgumentError, 'wrong'
      end
    end

    it 'should also raise the exception when in an ignored environment' do
      InfluxDB::Rails.configure { |config| config.ignored_environments = %w(development test) }

      expect do
        InfluxDB::Rails.rescue do
          raise ArgumentError, 'wrong'
        end
      end.to raise_error(ArgumentError)
    end
  end

  describe 'rescue_and_reraise' do
    it 'should transmit an exception when passed' do
      InfluxDB::Rails.configure { |config| config.ignored_environments = [] }

      expect(InfluxDB::Rails.client).to receive(:write_point)

      expect do
        InfluxDB::Rails.rescue_and_reraise { raise ArgumentError, 'wrong' }
      end.to raise_error(ArgumentError)
    end
  end
end
