require 'sinatra/base'

module ACM

  module Controller

    class ApiController < Sinatra::Base

      get '/objects/:object_id' do
        @logger.debug("Got request for #{params[:object_id]}")

      end


    end

  end
end