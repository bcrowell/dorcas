# I had a weird problem with Tempfile that I didn't understand, so hacked up this instead.

require 'digest'

def temp_file_name()
  return "/tmp/dorcas-"+Process.pid.to_s+"-"+Digest::MD5.hexdigest(Random.new.bytes(32))
end
