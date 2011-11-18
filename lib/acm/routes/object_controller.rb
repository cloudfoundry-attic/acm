require 'sinatra/base'

module ACM

  module Controller

    class ApiController < Sinatra::Base

      def initialize
        super
        @object_service = ACM::Services::ObjectService.new()
      end

      get '/objects/:object_id' do
        content_type 'application/json', :charset => 'utf-8'
        @logger.debug("GET request for /objects/#{params[:object_id]}")

        reponse = @object_service.read_object(params[:object_id])
        @log.debug("Response is #{reponse.inspect}")

        response
      end

      post '/objects' do
        content_type 'application/json', :charset => 'utf-8'
        @logger.debug("POST request for /objects")

        request_json = nil
        begin
          request_json = Yajl::Parser.new.parse(request.body)
        rescue => e
          @logger.error("Invalid request #{e.message}")
          raise ACM::InvalidRequest.new(e.message)
        end
        @logger.debug("decoded value is #{request_json.inspect}")


      end

    end

  end
end