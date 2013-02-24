#!/usr/bin/env ruby

require 'webrick'
require 'webrick/httpproxy'
require 'logger'

PROGNAME = File.basename($0, '.rb')

$conf = {
  :port => 8080,
#  :cache_dir => "/var/local/#{PROGNAME}",
#  :log_dir => "/var/log",
  :cache_dir => ".",
  :log_dir => ".",
  :log_rotation => "monthly",
}

class DistroCacheServer < WEBrick::HTTPProxyServer
 def proxy_service(req, res)
   if %r!/$! =~ req.path
     localfile = File.join($conf[:cache_dir], req.host, req.path, '_index.html')
   else
     localfile = File.join($conf[:cache_dir], req.host, req.path)
   end
     
   if File.file?(localfile)
     res.body = open(localfile).read
     res.header["Content-Type"] = WEBrick::HTTPUtils.mime_type(req.path_info, WEBrick::HTTPUtils::DefaultMimeTypes)
     return
   end

   super

   if /\.(rpm|deb)$/ =~ localfile
     FileUtils.mkdir_p(File.dirname(localfile))
     open(localfile, 'w') do |f|
       f.write(res.body)
     end
   end
 end
end


access_logger = Logger.new(File.join($conf[:log_dir], "#{PROGNAME}.log"), $conf[:log_rotation])
server_logger = Logger.new(File.join($conf[:log_dir], "#{PROGNAME}.out"), $conf[:log_rotation])
server_logger.level = Logger::INFO

s = DistroCacheServer.new(
  Port: $conf[:port],
  # ServerType: WEBrick::Daemon,
  AccessLog: [[access_logger, WEBrick::AccessLog::COMBINED_LOG_FORMAT]],
  Logger: server_logger
)

trap("INT"){ s.shutdown }
s.start
