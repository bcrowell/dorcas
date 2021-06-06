#!/bin/ruby

require 'json'

# Reads two input files, each containing a JSON hash.
# Merges them and writes the resulting JSON code to stdout.

def main()
  if ARGV.length!=2 then die("need 2 args") end
  in1 = ARGV[0]
  in2 = ARGV[1]
  m = json_from_file_or_die(in1).merge(json_from_file_or_die(in2))
  print JSON.generate(m)
end


# returns contents or nil on error; for more detailed error reporting, see slurp_file_with_detailed_error_reporting()
def slurp_file(file)
  x = slurp_file_with_detailed_error_reporting(file)
  return x[0]
end

# returns [contents,nil] normally [nil,error message] otherwise
def slurp_file_with_detailed_error_reporting(file)
  begin
    File.open(file,'r') { |f|
      t = f.gets(nil) # nil means read whole file
      if t.nil? then t='' end # gets returns nil at EOF, which means it returns nil if file is empty
      t = t.unicode_normalize(:nfc) # e.g., the constructor Job.from_file() depends on this
      return [t,nil]
    }
  rescue
    return [nil,"Error opening file #{file} for input: #{$!}."]
  end
end

def json_from_file_or_die(file)
  # automatically does unicode_normalize(:nfc)
  json,err = slurp_file_with_detailed_error_reporting(file)
  if !(err.nil?) then die(err) end
  return JSON.parse(json)
end

def json_from_file_or_stdin_or_die(file)
  if file=='-' then
    x = stdin.gets(nil)
    if x.nil? then return "" else return x end
  else
    return json_from_file_or_die(file)
  end
end

def dir_and_file_to_path(dir,file)
  return dir+"/"+file # bug: won't work on windows
end

def create_text_file(filename,text)
  File.open(filename,'w') { |f|
    f.print text
  }
end

def die(message)
  #  $stderr.print message,"\n"
  raise message # gives a stack trace
  exit(-1)
end

main()
