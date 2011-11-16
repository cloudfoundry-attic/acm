require 'acm/services/acm_service'

module ACM

  module Services

    class ObjectService < ACMService

      def create_object(opts)

        o = ACM::Models::Objects.new(
          :name => opts[:name],
          :additional_info => opts[:additional_info]
        )

        begin
          o.save
        rescue => e
          @logger.info("Failed to create an object #{e}")
          @logger.debug("Failed to create an object #{e.backtrace.inspect}")
          raise ACM::SystemInternalError.new()
        end

        o.to_json

      end

    end

  end

end
