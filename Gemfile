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

source :rubygems

gem "rack-test"         # needed for console
gem "rake"
gem "sequel"
gem "sinatra"
gem "SystemTimer", :platforms => :ruby_18
gem "thin"
gem "uuidtools"
gem "yajl-ruby", '~> 0.8.3'
gem "pg"
gem "eventmachine", "~> 0.12.11.cloudfoundry.3"
gem "nats"

group :development do
  gem "sqlite3"
end

group :production do
  gem "pg"
end

group :development, :test do
  gem "rspec"
  gem "sqlite3"
  gem "simplecov", :platforms => :ruby_19
  gem "simplecov-rcov", :platforms => :ruby_19
  gem "rcov", :platforms => :ruby_18
  gem "ci_reporter"
end

gem 'vcap_common', "= 1.0.10", :require => ['vcap/common', 'vcap/component']
gem "vcap_logging"
