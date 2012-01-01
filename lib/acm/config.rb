require "logger"
require "securerandom"
require "sequel"

require "acm/thread_formatter"
require "acm/utils"


module ACM

  module Config
    class << self

      #Configuration options that can be accessed throughout the app
      CONFIG_OPTIONS = [
        :logger,
        :log_file,
        :db,
        :name,
        :revision,
        :basic_auth,
        :pid_file,
        :acm_shutting_down
      ]

      CONFIG_OPTIONS.each do |option|
        attr_accessor option
      end

      alias :acm_shutting_down? :acm_shutting_down

      def clear
        CONFIG_OPTIONS.each do |option|
          self.instance_variable_set("@#{option}".to_sym, nil)
        end
      end

      #Called by the acm binary to consume the configuration and set up the app
      def configure(config)
        @log_file = config["logging"]["file"] || STDOUT
        @logger = Logger.new(@log_file, "daily")
        @logger.level = Logger.const_get(config["logging"]["level"].upcase)
        @logger.formatter = ThreadFormatter.new

        Dir.chdir(File.expand_path("..", __FILE__))
        @revision = `(git show-ref --head --hash=8 2> /dev/null || echo 00000000) | head -n1`.strip

        @name = config["name"] || ""

        @pid_file = config["pid"]
        create_pid_file(@pid_file)

        if config["db"]["database"].index("sqlite://") == 0
          patch_sqlite
        end

        connection_options = {}
        [:max_connections, :pool_timeout].each { |key| connection_options[key] = config["db"][key.to_s] }

        @db = Sequel.connect(config["db"]["database"], connection_options)

        puts("Database connection successful")
        @db.logger = @logger
        @db.sql_log_level = config["logging"]["level"].downcase.to_sym

        #Run the db migrations if they have not already been run
        Sequel.extension :migration
        Sequel::Migrator.apply(@db, '../../db/migrations')

        Sequel::Model.plugin :validation_helpers

        @basic_auth = {:user => config["basic_auth"]["user"], :password => config["basic_auth"]["password"]}

        puts("Configuration complete")
        @logger.debug("ACM running #{@revision}")
        if(!@log_file.nil?)
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
