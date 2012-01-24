$:.unshift(File.expand_path("../../lib", __FILE__))

ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../../Gemfile", __FILE__)
require "rubygems"
require "bundler"
Bundler.setup(:default, :test)

require "rspec"

ENV["RACK_ENV"] = "test"

require "logger"
if ENV['DEBUG']
  logger = Logger.new(STDOUT)
else
  path = File.expand_path("../spec.log", __FILE__)
  log_file = File.open(path, "w")
  log_file.sync = true
  logger = Logger.new(log_file)
end

require "acm/config"

ACM::Config.patch_sqlite

migrate_dir = File.expand_path("../../db/migrations", __FILE__)
Sequel.extension :migration
db = Sequel.sqlite(:database => nil, :max_connections => 32, :pool_timeout => 10)
db.loggers << logger
Sequel::Model.db = db
Sequel::Migrator.apply(db, migrate_dir, nil)


$:.unshift(File.expand_path("lib", __FILE__))
$:.unshift(File.expand_path("lib/acm", __FILE__))
$:.unshift(File.expand_path("lib/acm/models", __FILE__))
$:.unshift(File.expand_path("lib/acm/routes", __FILE__))

require "acm_controller"

require "digest/sha1"
require "fileutils"
require "tmpdir"
require "zlib"

acm_dir = Dir.mktmpdir("acm_dir")
acm_tmp_dir = Dir.mktmpdir("acm_tmp_dir")

ENV["TMPDIR"] = acm_tmp_dir

logger.formatter = ThreadFormatter.new


def spec_asset(filename)
  File.read(File.expand_path("../assets/#{filename}", __FILE__))
end

Rspec.configure do |rspec_config|

  rspec_config.before(:each) do |example|
    ACM::Config.clear

    db.execute("PRAGMA foreign_keys = OFF")
    db.tables.each do |table|
      db.drop_table(table)
    end
    db.execute("PRAGMA foreign_keys = ON")

    Sequel::Migrator.apply(db, migrate_dir, nil)
    FileUtils.mkdir_p(acm_dir)
    ACM::Config.logger = logger
    ACM::Config.db = db
    ACM::Config.basic_auth = { :user => :admin.to_s, :password => :password.to_s }
    ACM::Config.default_schema_version = "urn:acm:schemas:1.0"

    logger.info("Start test #{example.example.metadata[:full_description]}")

  end

  rspec_config.after(:each) do |example|
    FileUtils.rm_rf(acm_dir)
    logger.info("End test #{example.example.metadata[:full_description]}")
  end

  rspec_config.after(:all) do
    FileUtils.rm_rf(acm_tmp_dir)
  end
end

if defined?(Rcov)
  class Rcov::CodeCoverageAnalyzer
    def update_script_lines__
      if '1.9'.respond_to?(:force_encoding)
        SCRIPT_LINES__.each do |k,v|
          v.each { |src| src.force_encoding('utf-8') }
        end
      end
      @script_lines__ = @script_lines__.merge(SCRIPT_LINES__)
    end
  end
end

