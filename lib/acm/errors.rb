# Cloud Foundry 2012.02.03 Beta
# Copyright (c) [2009-2012] VMware, Inc. All Rights Reserved. 
# 
# This product is licensed to you under the Apache License, Version 2.0 (the "License").  
# You may not use this product except in compliance with the License.  
# 
# This product includes a number of subcomponents with
# separate copyright notices and license terms. Your use of these
# subcomponents is subject to the terms and conditions of the 
# subcomponent's license, as noted in the LICENSE file. 

# Default error classes for the ACM
module ACM

  OK                    = 200
  CREATED               = 201
  NO_CONTENT            = 204

  BAD_REQUEST           = 400
  UNAUTHORIZED          = 401
  FORBIDDEN             = 403
  NOT_FOUND             = 404

  INTERNAL_SERVER_ERROR = 500

  #Error class for the ACM
  class ACMError < StandardError
    attr_reader :response_code
    attr_reader :error_code

    def initialize(response_code, error_code, format, *args)
      @response_code = response_code
      @error_code = error_code
      msg = sprintf(format, *args)
      super(msg)
    end
  end

  #Each of the strings below is used
  #to create an error class with the same name
  [
   ["ObjectNotFound",        NOT_FOUND,   1000, "Object %s not found"],
   ["InvalidRequest",        BAD_REQUEST, 1001, "Invalid request: \"%s\""],
   ["Unauthorized",          UNAUTHORIZED, 1002, "Unauthorized"],

   ["SystemInternalError",   INTERNAL_SERVER_ERROR,   2000, "An unknown error occurred" ]

  ].each do |e|
    class_name, response_code, error_code, format = e

    klass = Class.new ACMError do
      define_method :initialize do |*args|
        super(response_code, error_code, format, *args)
      end
    end

    ACM.const_set(class_name, klass)
  end

end
