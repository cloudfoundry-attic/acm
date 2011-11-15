require "monitor"
require "logger"
require "securerandom"

require "acm/thread_formatter"


module ACM

  class Config

    class << self

      CONFIG_OPTIONS = [
        :base_dir,
        :logger,
        :db,
        :name,
        :revision,
        :basic_auth
      ]

      CONFIG_OPTIONS.each do |option|
        attr_accessor option
      end

      def clear
        CONFIG_OPTIONS.each do |option|
          self.instance_variable_set("@#{option}".to_sym, nil)
        end
      end

      def configure(config)
        @base_dir = config["dir"]
        FileUtils.mkdir_p(@base_dir)

        @logger = Logger.new(config["logging"]["file"] || STDOUT)
        @logger.level = Logger.const_get(config["logging"]["level"].upcase)
        @logger.formatter = ThreadFormatter.new

        Dir.chdir(File.expand_path("..", __FILE__))
        @revision = `(git show-ref --head --hash=8 2> /dev/null || echo 00000000) | head -n1`.strip

        @name = config["name"] || ""

        if config["db"]["database"].index("sqlite://") == 0
          patch_sqlite
        end

        connection_options = {}
        [:max_connections, :pool_timeout].each { |key| connection_options[key] = config["db"][key.to_s] }

        @db = Sequel.connect(config["db"]["database"], connection_options)

        puts("Database connection successful #{@db.inspect}")
        @db.logger = @logger
        @db.sql_log_level = :debug
        Sequel::Model.plugin :validation_helpers

        @lock = Monitor.new

        puts "Configuration complete"
        @logger.debug("ACM running")

        @basic_auth = { :user => config["basic_auth"]["user"], :password => config["basic_auth"]["password"]}

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
