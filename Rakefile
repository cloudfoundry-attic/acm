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

require 'rake'

desc "Run specs"
task "spec" => ["bundler:install:test", "test:spec"]

desc "Run functional tests"
task "spec:unit" => ["bundler:install:test", "test:spec:unit"]

desc "Run functional tests"
task "spec:functional" => ["bundler:install:test", "test:spec:functional"]

desc "Run specs using RCov"
task "spec:cov" => ["bundler:install:test", "test:spec:rcov"]

desc "Run specs using RCov"
task "spec:ci" => ["test:spec:ci"]

namespace "bundler" do

  desc "Install gems"
  task "install" do
    sh("bundle install")
  end

  environments = %w(test development production)

  environments.each do |env|
    desc "Install gems for #{env}"
    task "install:#{env}" do
      sh("bundle install --local --without #{(environments - [env]).join(' ')}")
    end
  end

end

namespace "test" do

  ["spec", "spec:unit", "spec:functional", "spec:rcov", "spec:ci"].each do |task_name|
    task task_name do
      sh("cd spec && rake #{task_name}")
    end
  end

end
