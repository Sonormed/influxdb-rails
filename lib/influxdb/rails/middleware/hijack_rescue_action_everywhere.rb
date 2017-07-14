module InfluxDB
  module Rails
    module Middleware
      module HijackRescueActionEverywhere
        def self.included(base)
          base.send(:alias_method_chain, :rescue_action_in_public, :influxdb)
          base.send(:alias_method_chain, :rescue_action_locally, :influxdb)
        end

        private

        def rescue_action_in_public_with_influxdb(e)
          handle_exception(e)
          rescue_action_in_public_without_influxdb(e)
        end

        def rescue_action_locally_with_influxdb(e)
          handle_exception(e)
          rescue_action_locally_without_influxdb(e)
        end

        def handle_exception(e)
          request_data = influxdb_request_data || {}
          return if InfluxDB::Rails.configuration.ignore_user_agent?(request_data[:user_agent])
          InfluxDB::Rails.report_exception_unless_ignorable(e, request_data)
        end
      end
    end
  end
end
