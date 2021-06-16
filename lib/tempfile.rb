# I had a weird problem with Tempfile that I didn't understand, so hacked up this instead.

require 'digest'

def temp_file_name()
  return "/tmp/dorcas-"+Process.pid.to_s+"-"+Digest::MD5.hexdigest(Random.new.bytes(32))
  # This convention that files are of the form "/tmp/dorcas*" is also assumed in verb_clean().
  # This won't work on Windows.
end

def temp_file_name_short(prefix:"/tmp/dorcas") # for files the use needs to see, and for which collisions are not a big deal
  id = sprintf("%02d",Process.pid % 100)
  return prefix+"-"+id+"-"+Digest::MD5.hexdigest(Random.new.bytes(6))[0,6]
end
