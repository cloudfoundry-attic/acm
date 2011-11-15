require 'acm/errors'
require 'acm_controller'
require 'sinatra/base'
require 'json'
require 'net/http'

module ACM

  module Controller

    class ApiController < Sinatra::Base

      def initialize
        super
        @logger = Config.logger
        @logger.debug("ApiController is up")
      end

      use Rack::Auth::Basic, "Restricted Area" do |username, password|
        [username, password] == [Config.basic_auth[:user], Config.basic_auth[:password]]
      end

      ###################  /token_info  ###################

      def uri_to(path)
        URI::HTTP.build({:host => Config.uaa[:host],
                        :port => Config.uaa[:port],
                        :path => "#{Config.uaa[:context]}#{path}"
                       })
      end

      post '/token_info' do
        content_type 'application/json', :charset => 'utf-8'

        token = params[:token]
        @logger.debug("token_info call for token #{token}")

        begin
          uri = uri_to("/check_token")
          @logger.error("URI for this operation is #{uri.inspect}")
          http = Net::HTTP.new(uri.host, uri.port)
          req = Net::HTTP::Post.new(uri.request_uri)
          req.basic_auth(Config.uaa[:user], Config.uaa[:password])
          if(token.include? "Bearer")
            stripped_token = token.gsub("Bearer ", "")
            req.set_form_data({"token" => stripped_token})
          else
            req.set_form_data({"token" => token})
          end

          res = http.request(req)

          @logger.debug("Response is #{res.body.inspect}")
        rescue StandardError => e
          @logger.error("Failed to fetch the authentication url #{e.inspect}")
          raise e
        end

        res.body
      end

      ###################  /token_info  ###################


      ###################  authorizer /org/project/authorized ###################

      post '/:org_context/:project_context/authorized' do
        content_type 'application/json', :charset => 'utf-8'


      end

      ###################  authorizer /org/project/authorized ###################


      ###################  resource creation /org/project/resource_type ###################

      #TODO: Request response logging
      post '/:org_context/:project_context/:resource_type' do
        content_type 'application/json', :charset => 'utf-8'
        response = nil

        #TODO: Schema/input validation
        case params[:resource_type].to_sym
          when :org
            response = createOrg(params, request)
          else
            response = createResource(params, request, params[:resource_type])
        end

        @logger.debug("Response is #{response.inspect}")
        response

      end

      def createOrg(params, request)
        org_context, project_context = get_context(params)
        user = get_user(request)

        @logger.debug("Received request from #{user}")
        request_json = nil
        begin
          request_json = Yajl::Parser.new.parse(request.body)
        rescue => e
          @logger.error("Invalid request #{e.message}")
          raise ACM::InvalidRequest.new(e.message)
        end
        @logger.debug("decoded value is #{request_json.inspect}")

        input_hash = process_org_input(request_json)

        org_service = ACM::Services::OrganizationService.new(:authenticated_user => user,
                                                                    :org => org_context,
                                                                    :project => project_context)
        org = org_service.create(:name => input_hash[:name],
                               :description => input_hash[:description],
                               :authentication_endpoint => input_hash[:authentication_endpoint])

        org.to_json()
      end

      def process_org_input(request)
        return_hash = {}

        return_hash[:name] = request[:name.to_s]
        return_hash[:description] = request[:description.to_s]
        return_hash[:authentication_endpoint] = request[:authenticationEndpoint.to_s]
        return_hash[:schema] = "urn:ACM:schemas:1.0"

        return_hash
      end

      def createResource(params, request, resource_type)
        org_context, project_context = get_context(params)
        user = get_user(request)

        @logger.debug("Received request #{request.body.inspect} from #{user}")
        request_json = Yajl::Parser.new.parse(request.body)
        @logger.debug("decoded value is #{request_json.inspect}")

        organization_service = ACM::Services::OrganizationService.new(:authenticated_user => user,
                                                                          :org => org_context,
                                                                          :project => project_context)

        org_entity = organization_service.find_organization()

        project_service = ACM::Services::ProjectService.new(:authenticated_user => user,
                                                                  :org => org_context,
                                                                  :project => project_context)
        project_entity = project_service.find_project()

        resource_service = ACM::Services::ResourceService.new(:authenticated_user => user,
                                                                    :org => org_context,
                                                                    :project => project_context)

        if(!request_json[:resource_metadata.to_s].nil?)
          begin
            resource_metadata = Hash.try_convert(request_json[:resource_metadata.to_s])
          rescue => e
            @logger.error("Failed to parse resource_metadata for \
                          resource #{request_json[:name.to_s]} type #{resource_type} \
                          metadata is #{request_json[:resource_metadata.to_s].inspect}")
          end
        end

        @logger.debug("Resource metadata is #{resource_metadata.inspect}")
        resource = resource_service.create(resource_type,
                                        request_json[:name.to_s],
                                        request_json[:description.to_s],
                                        resource_metadata.to_json)

        resource.to_json()
      end

      ###################  resource creation /org/project/resource_type ###################


      ###################  resource deletion /org/project/resource_type ###################

      delete '/:org_context/:project_context/:resource_type' do
        content_type 'application/json', :charset => 'utf-8'
        response = nil

        #TODO: Schema/input validation
        resource_type = params[:resource_type]
        case params[:resource_type].to_sym
          when :org
            response = deleteOrg(params, request)
          else
            response = deleteResource(params, request, params[:resource_type])
        end


        @logger.debug("Response is #{response.inspect}")
        response

      end

      def deleteOrg(params, request)
        org_context, project_context = get_context(params)
        user = get_user(request)

        @logger.debug("Received request from #{user}")
        request_json = nil
        begin
          request_json = Yajl::Parser.new.parse(request.body)
        rescue => e
          @logger.error("Invalid request #{e.message}")
          raise ACM::InvalidRequest.new(e.message)
        end
        @logger.debug("decoded value is #{request_json.inspect}")

        org_name = request[:name.to_s]

        org_service = ACM::Services::OrganizationService.new(:authenticated_user => user,
                                                                    :org => org_context,
                                                                    :project => project_context)
        org_service.delete(org_name)

        operation_success_info
      end

      def operation_success_info
        {
            :code => 0,
            :description => :Success
        }.to_json()
      end

      def deleteResource(params, request, resource_type)

      end

      ###################  resource deletion /org/project/resource_type ###################


      ###################  resource fetch /org/project/resource_type ###################

      get '/:org_context/:project_context/:resource_type/:resource_name' do
        content_type 'application/json', :charset => 'utf-8'
        response = nil

        #TODO: Schema/input validation
        case params[:resource_type].to_sym
          when :org
            response = getOrg(params, request)
          else
            response = getResource(params, request, params[:resource_type])
        end

        if(response.nil?)
          raise ACM::ResourceNotFound.new("Name: #{params[:resource_name]} Type #{params[:resource_type]}")
        end

        @logger.debug("Response is #{response.inspect}")
        response
      end

      def getOrg(params, request)
        org_context, project_context = get_context(params)
        user = get_user(request)
        org_name = params[:resource_name]

        @logger.debug("Received request from #{user}")
        request_json = Yajl::Parser.new.parse(request.body)
        @logger.debug("decoded value is #{request_json.inspect}")

        org_service = ACM::Services::OrganizationService.new(:authenticated_user => user,
                                                                    :org => org_context,
                                                                    :project => project_context)
        org = org_service.find_organization(org_name)

        if(!org.nil?)
          org.to_json()
        else
          raise ACM::ResourceNotFound.new("Name: #{params[:resource_name]} Type #{params[:resource_type]}")
        end

      end


      def getResource(params, request, resource_type)
        org_context, project_context = get_context(params)
        user = get_user(request)
        resource_name = params[:resource_name]
        resource_type = params[:resource_type]

        @logger.debug("Received request from #{user}")
        request_json = Yajl::Parser.new.parse(request.body)
        @logger.debug("decoded value is #{request_json.inspect}")

        resource_service = ACM::Services::ResourceService.new(:authenticated_user => user,
                                                                    :org => org_context,
                                                                    :project => project_context)
        resource = resource_service.find_resource()

        if(!resource.nil?)
          resource.to_json(resource_name, resource_type)
        else
          nil
        end

      end

      def get_context(params)
        @logger.debug("Post params #{params}")
        return params[:org_context], params[:project_context]
      end

      def get_user(request)
        @logger.debug("authz headers #{request.env[:AUTHORIZATION.to_s].inspect}")
        user_token = request.env[:AUTHORIZATION.to_s]

        if(user_token.nil?)
          return nil
        end

        @logger.debug("token_info call for token #{user_token}")

        begin
          uri = uri_to("/check_token")
          @logger.error("URI for this operation is #{uri.inspect}")
          http = Net::HTTP.new(uri.host, uri.port)
          req = Net::HTTP::Post.new(uri.request_uri)
          req.basic_auth(Config.uaa[:user], Config.uaa[:password])
          if(user_token.include? "Bearer")
            stripped_token = token.gsub("Bearer ", "")
            req.set_form_data({"token" => stripped_token})
          else
            req.set_form_data({"token" => token})
          end

          res = http.request(req)

          @logger.debug("Response is #{res.body.inspect}")
        rescue StandardError => e
          @logger.error("Failed to fetch the authentication url #{e.inspect}")
          raise e
        end

        if(res.code == "200")
          token_as_hash = Yajl::Parser.new.parse(res.body)

          token_as_hash[:user_id.to_s]
        else
          @logger.debug("Problem with check_token request to the uaa: #{res.inspect}")
          raise ACM::SystemInternalError.new()
        end

      end

      ###################  resource fetch /org/project/resource_type ###################

      ###################  resource update /org/project/resource_type ###################

      put '/:org_context/:project_context/:resource_type/:resource_name' do
        content_type 'application/json', :charset => 'utf-8'
        response = nil

        #TODO: Schema/input validation
        case params[:resource_type].to_sym
          when :org
            response = updateOrg(params, request)
          when :project
            response = updateProject(params, request)
          else
            response = updateResource(params, request, params[:resource_type])
        end

        response
      end

      def updateOrg(params, request)
        #TODO: Not implemented
        nil
      end

      def updateProject(params, request)
        org_context, project_context = get_context(params)
        user = get_user(request)

        project_service = ACM::Services::ProjectService
      end

      def updateResource(params, request, resource_type)
        #TODO: Not implemented
        nil
      end

      ###################  resource update /org/project/resource_type ###################

      configure do
        set(:show_exceptions, false)
        set(:raise_errors, false)
        set(:dump_errors, true)
      end

      error do
        content_type 'application/json', :charset => 'utf-8'

        @logger.debug("Reached error handler")
        exception = request.env["sinatra.error"]
        if exception.kind_of?(ACMError)
          @logger.debug("Request failed with response code: #{exception.response_code} error code: " +
                           "#{exception.error_code} error: #{exception.message}")
          status(exception.response_code)
          error_payload                = Hash.new
          error_payload['code']        = exception.error_code
          error_payload['description'] = exception.message
          #TODO: Handle meta and uri. Exception class to contain to_json
          Yajl::Encoder.encode(error_payload)
        else
          msg = ["#{exception.class} - #{exception.message}"]
          @logger.warn(msg.join("\n"))
          status(500)
        end
      end

      not_found do
        content_type 'application/json', :charset => 'utf-8'

        @logger.debug("Reached not_found handler")
        status(404)
        error_payload                = Hash.new
        error_payload['code']        = ACM::ResourceNotFound.new("").error_code
        error_payload['description'] = "The resource was not found"
        #TODO: Handle meta and uri
        Yajl::Encoder.encode(error_payload)
      end

    end

  end

end
