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

# Copyright (c) 2009-2011 VMware, Inc.

def create_pid_file(pidfile)
  # Make sure dirs exist.
  begin
    FileUtils.mkdir_p(File.dirname(pidfile))
  rescue => e
     ACM::Config.logger.fatal("Can't create pid directory, exiting: #{e}")
  end
  File.open(pidfile, 'w') { |f| f.puts "#{Process.pid}" }
end

require "vcap/component"
module ACM
  class Varz

    class << self
      def setup_updates
        @timestamp = Time.now
        @current_num_requests = 0
        EM.add_periodic_timer(1) { update_requests_per_sec }
      end

      def update_requests_per_sec
        # Update our timestamp and calculate delta for reqs/sec
        now = Time.now
        delta = now - @timestamp
        @timestamp = now
        # Now calculate Requests/sec
        new_num_requests = VCAP::Component.varz[:requests]
        VCAP::Component.varz[:requests_per_sec] = ((new_num_requests - @current_num_requests)/delta.to_f).to_i
        @current_num_requests = new_num_requests
      end
    end
  end
end
