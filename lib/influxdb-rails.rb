require 'net/http'
require 'net/https'
require 'rubygems'
require 'socket'
require 'thread'

require 'influxdb/rails/version'
require 'influxdb/rails/logger'
require 'influxdb/rails/exception_presenter'
require 'influxdb/rails/configuration'
require 'influxdb/rails/backtrace'
require 'influxdb/rails/rack'

require 'influxdb/rails/railtie' if defined?(Rails::Railtie)

module InfluxDB
  module Rails
    class << self
      include InfluxDB::Rails::Logger

      attr_writer :configuration
      attr_writer :client

      def configure(_silent = false)
        yield(configuration)

        # if we change configuration, reload the client
        self.client = nil

        InfluxDB::Logging.logger = configuration.logger unless configuration.logger.nil?
      end

      def client
        @client ||= InfluxDB::Client.new configuration.influxdb_database,

                                         username: configuration.influxdb_username,
                                         password: configuration.influxdb_password,
                                         hosts: configuration.influxdb_hosts,
                                         port: configuration.influxdb_port,
                                         async: configuration.async,
                                         use_ssl: configuration.use_ssl,
                                         retry: configuration.retry
      end

      def configuration
        @configuration ||= InfluxDB::Rails::Configuration.new
      end

      def report_exception_unless_ignorable(e, env = {})
        report_exception(e, env) unless ignorable_exception?(e)
      end
      alias transmit_unless_ignorable report_exception_unless_ignorable

      def report_exception(e, env = {})
        env = influxdb_request_data if env.empty? && defined? influxdb_request_data
        exception_presenter = ExceptionPresenter.new(e, env)
        log :info, "Exception: #{exception_presenter.to_json[0..512]}..."

        ex_data = exception_presenter.context.merge(exception_presenter.dimensions)
        timestamp = ex_data.delete(:time)

        client.write_point 'rails.exceptions', values: {
          ts: timestamp
        },
                                               tags: ex_data,
                                               timestamp: timestamp
      rescue => e
        log :info, "[InfluxDB::Rails] Something went terribly wrong. Exception failed to take off! #{e.class}: #{e.message}"
      end
      alias transmit report_exception

      def handle_action_controller_metrics(_name, start, finish, _id, payload)
        controller_runtime = ((finish - start) * 1000).ceil
        view_runtime = (payload[:view_runtime] || 0).ceil
        db_runtime = (payload[:db_runtime] || 0).ceil
        method = "#{payload[:controller]}##{payload[:action]}"
        hostname = Socket.gethostname

        begin
          client.write_point configuration.series_name_for_controller_runtimes, values: {
            value: controller_runtime
          },
                                                                                tags: {
                                                                                  method: method,
                                                                                  server: hostname
                                                                                }

          client.write_point configuration.series_name_for_view_runtimes, values: {
            value: view_runtime
          },
                                                                          tags: {
                                                                            method: method,
                                                                            server: hostname
                                                                          }

          client.write_point configuration.series_name_for_db_runtimes, values: {
            value: db_runtime
          },
                                                                        tags: {
                                                                          method: method,
                                                                          server: hostname
                                                                        }
          client.write_point configuration.series_name_for_total_runtimes, values: {
            value: controller_runtime + view_runtime + db_runtime
          },
                                                                           tags: {
                                                                             method: method,
                                                                             server: hostname
                                                                           }
        rescue => e
          log :error, "[InfluxDB::Rails] Unable to write points: #{e.message}"
        end
      end

      def handle_sql_metrics(_name, start, finish, _id, payload)
        client.write_point configuration.series_name_for_sql_runtimes, values: {
          value: ((finish - start) * 1000).ceil
        },
                                                                       tags: {
                                                                         caller: "'#{caller.detect { |path| path.to_s =~ /#{::Rails.root}/ }.to_s.to_s.gsub(/'/, "\\\\'")}'",
                                                                         server: Socket.gethostname.to_s,
                                                                         sql: "'#{payload[:sql].to_s.gsub(/'/, "\\\\'")}'"
                                                                       }
      rescue => e
        log :error, "[InfluxDB::Rails] Unable to write points: #{e.message}"
      end

      def current_timestamp
        Time.now.utc.to_i
      end

      def ignorable_exception?(e)
        configuration.ignore_current_environment? ||
          !!configuration.ignored_exception_messages.find { |msg| /.*#{msg}.*/ =~ e.message } ||
          configuration.ignored_exceptions.include?(e.class.to_s)
      end

      def rescue
        yield
      rescue StandardError => e
        raise(e) if configuration.ignore_current_environment?
        transmit_unless_ignorable(e)
      end

      def rescue_and_reraise
        yield
      rescue StandardError => e
        transmit_unless_ignorable(e)
        raise(e)
      end

      def safely_prepend(module_name, opts = {})
        return if opts[:to].nil? || opts[:from].nil?
        if opts[:to].respond_to?(:prepend, true)
          opts[:to].send(:prepend, opts[:from].const_get(module_name))
        else
          opts[:to].send(:include, opts[:from].const_get('Old' + module_name))
        end
      end
    end
  end
end
