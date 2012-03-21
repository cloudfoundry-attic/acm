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

require "vcap/logging"
require "securerandom"
require "sequel"

require "acm/utils"


module ACM

  module Config
    class << self

      #Configuration options that can be accessed throughout the app
      CONFIG_OPTIONS = [
        :logger,
        :log_level,
        :log_file,
        :db,
        :name,
        :revision,
        :basic_auth,
        :pid_file,
        :default_schema_version
      ]

      CONFIG_OPTIONS.each do |option|
        attr_accessor option
      end

      def clear
        CONFIG_OPTIONS.each do |option|
          self.instance_variable_set("@#{option}".to_sym, nil)
        end
      end

      #Called by the acm binary to consume the configuration and set up the app
      def configure(config)
        @pid_file = config["pid"]
        create_pid_file(@pid_file)

        @default_schema_version = "urn:acm:schemas:1.0"

        VCAP::Logging.setup_from_config(config["logging"])
        @logger = VCAP::Logging.logger("acm")
        @log_level = config["logging"]["level"].to_sym

        Dir.chdir(File.expand_path("..", __FILE__))
        @revision = `(git show-ref --head --hash=8 2> /dev/null || echo 00000000) | head -n1`.strip

        @name = config["name"] || ""

        if config["db"]["database"].index("sqlite://") == 0
          patch_sqlite
        end

        connection_options = {}
        [:max_connections, :pool_timeout].each { |key| connection_options[key] = config["db"][key.to_s] }

        @db = Sequel.connect(config["db"]["database"], connection_options)

        if config["logging"] && config["logging"]["level"] == "debug"
          @db.logger = @logger
          @db.sql_log_level = :debug
        else
          @db.logger = nil
        end

        #Run the db migrations if they have not already been run
        Sequel.extension :migration
        Sequel::Migrator.apply(@db, '../../db/migrations')
        puts("Database connection successful")

        Sequel::Model.plugin :validation_helpers

        @basic_auth = {:user => config["basic_auth"]["user"], :password => config["basic_auth"]["password"]}

        puts("Configuration complete")
        @logger.info("ACM running #{@revision}")
        unless @log_file.nil?
          puts("Logs are at #{@log_file}")
        end
      end

      def logger=(logger)
        @logger = logger
      end

      def patch_sqlite
        require "sequel"
        require "sequel/adapters/sqlite"

        Sequel::SQLite::Database.class_eval do
          def connect(server)
            opts = server_opts(server)
            opts[:database] = ':memory:' if blank_object?(opts[:database])
            db = ::SQLite3::Database.new(opts[:database])
            db.busy_handler do |retries|
              ACM::Config.logger.debug "SQLITE BUSY, retry ##{retries}"
              sleep(0.1)
              retries < 20
            end

            connection_pragmas.each { |s| log_yield(s) { db.execute_batch(s) } }

            class << db
              attr_reader :prepared_statements
            end
            db.instance_variable_set(:@prepared_statements, {})

            db
          end
        end
      end
    end
  end
end
