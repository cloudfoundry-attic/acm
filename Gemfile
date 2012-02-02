
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

group :development do
  gem "sqlite3"
end

group :production do
  gem "pg"
end

group :test do
  gem "rspec"
  gem "sqlite3"
  gem "simplecov", :platforms => :ruby_19
  gem "ci_reporter"
end
