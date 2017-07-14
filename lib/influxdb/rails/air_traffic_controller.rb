module InfluxDB
  module Rails
    module AirTrafficController
      def influxdb_request_data
        unfiltered_params = params.to_hash
        filtered_params = if respond_to?(:filter_parameters)
                            filter_parameters(unfiltered_params)
                          elsif defined? request.filtered_parameters
                            request.filtered_parameters
                          else
                            unfiltered_params.except(:password, :password_confirmation)
                          end

        {
          params: filtered_params,
          session_data: influxdb_session_data,
          controller: params[:controller],
          action: params[:action],
          request_url: influxdb_request_url,
          user_agent: request.env['HTTP_USER_AGENT'],
          remote_ip: request.remote_ip,
          referer: request.referer,
          current_user: (begin
                              current_user
                            rescue
                              nil
                            end)
        }
      end

      private

      def influxdb_session_data
        session.respond_to?(:to_hash) ? session.to_hash : session.data
      end

      def influxdb_request_url
        url = "#{request.protocol}#{request.host}"
        url << ":#{request.port}" unless [80, 443].include?(request.port)
        url << request.fullpath
      end
    end
  end
end
