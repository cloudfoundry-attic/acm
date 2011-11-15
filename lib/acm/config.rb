require "monitor"
require "logger"
require "securerandom"

require "collab_spaces/thread_formatter"


module CollabSpaces

  class Config

    class << self

      CONFIG_OPTIONS = [
        :base_dir,
        :logger,
        :db,
        :name,
        :revision,
        :uaa,
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

        create_default_org_and_project()

        @lock = Monitor.new

        puts "Configuration complete"
        @logger.debug("Collab Spaces running")

        #@show_exceptions = config["sinatra"]["show_exceptions"]
        #@raise_errors = config["sinatra"]["raise_errors"]
        #@dump_errors = config["sinatra"]["dump_errors"]

        @uaa = { :host => "localhost", :port => 8080, :context => "/cloudfoundry-identity-uaa", :user => "app", :password => "appclientsecret" }

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
              CollabSpaces::Config.logger.debug "SQLITE BUSY, retry ##{retries}"
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

      def create_default_org_and_project()

        @logger.debug("Is default org available?")
        ds = @db[:resources]
        all_org = ds.filter(:name => :all.to_s, :type => :organization.to_s).all()
        if(all_org.nil? || all_org.size() == 0)
          @logger.debug("Creating default org")
          @db[:resources].insert(:id => -1,
                                 :name => "all",
                                 :owner_id => -1,
                                 :type => "organization",
                                 :description => "Root cloudfoundry org",
                                 :immutable_id => SecureRandom.uuid,
                                 :created_at => Time.now,
                                 :last_updated_at => Time.now)
          @db[:resources].insert(:id => -2,
                                 :name => "all",
                                 :owner_id => -1,
                                 :type => "project",
                                 :description => "Project for the root cloudfoundry org",
                                 :immutable_id => SecureRandom.uuid,
                                 :created_at => Time.now,
                                 :last_updated_at => Time.now)
          @db[:resources].insert(:id => -3,
                                 :name => "organization",
                                 :owner_id => -1,
                                 :type => "resource_type",
                                 :description => "Organization resource type for the root cloudfoundry org",
                                 :immutable_id => SecureRandom.uuid,
                                 :created_at => Time.now,
                                 :last_updated_at => Time.now)
        else
          @logger.debug("Yes")
        end

      end

    end
  end
end
