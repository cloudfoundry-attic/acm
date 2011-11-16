require 'acm/services/acm_service'

module ACM

  module Services

    class ObjectService < ACMService

      def create_object(opts = nil)

        o = ACM::Models::Objects.new(
          :name => !opts.nil? ? opts[:name] : nil,
          :additional_info => !opts.nil? ? opts[:additional_info] : nil
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
