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

