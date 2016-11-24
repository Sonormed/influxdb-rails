module InfluxDB
  module Rails
    class Backtrace
      class Line
        FORMAT = /^((?:[a-zA-Z]:)?[^:]+):(\d+)(?::in `([^']+)')?$/

        attr_reader :file
        attr_reader :number
        attr_reader :method

        def initialize(line)
          _, @file, @number, @method = line.match(FORMAT).to_a
        end

        def to_s
          "#{file}:#{number} in `#{method}'"
        end

        def inspect
          "<Line: #{self}>"
        end
      end

      attr_reader :lines

      def initialize(backtrace)
        @lines = Array(backtrace).each.collect do |line|
          InfluxDB::Rails.configuration.backtrace_filters.each do |filter|
            line = filter.call(line)
          end
          Line.new(line)
        end
      end

      def to_a
        lines.map(&:to_s)
      end

      def inspect
        '<Backtrace: ' + lines.collect(&:to_s).join(', ') + '>'
      end
    end
  end
end
