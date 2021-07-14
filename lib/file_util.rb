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
  begin
    return JSON.parse(json)
  rescue
    die("error parsing JSON in file #{file}")
  end
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
  # I'm not sure what happens with this on windows. For glob(), it appears from the docs that using / rather than \ is actually mandatory
  # on windows. Not sure about things like File.open.
  return dir+"/"+file
end

def create_text_file(filename,text)
  File.open(filename,'w') { |f|
    f.print text
  }
end

def parse_json_or_warn(json,warning)
  # Occasionally it happens that the peaks file gets one line of garbled data in it. We don't just want to crash in that situation.
  begin
    return JSON.parse(json)
  rescue JSON::ParserError
    warn(warning)
    return nil
  end
end

def delete_files(files_to_delete)
  files_to_delete.each { |f|
    FileUtils.rm_f(f)
  }
end

def force_ext(filename,ext)
  # ext should be like "svg", not ".svg"
  result = shallow_copy(filename)
  if result=~/\.\w+$/ then
    return result.gsub(/\.\w*$/,".#{ext}")
  else
    return result+".#{ext}"
  end
end

def file_fingerprint(filename,n_dig:8)
  if filename.nil? then return nil end
  s = File::Stat.new(filename) 
  return Digest::MD5.hexdigest(s.ino.to_s+","+latest_modification(filename).to_r.to_s)[0..n_dig-1]
  # ... I believe the ino call is actually cross-platform.
end

def latest_modification(file_or_dir)
  # If it's a directory, recursively checks for the most recent modification to any subdirectory.
  times = [File::Stat.new(file_or_dir).mtime] # will throw an error if file doesn't exist
  if File.directory?(file_or_dir) then
    Dir.each_child(file_or_dir) { |f| times.push(latest_modification(dir_and_file_to_path(file_or_dir,f))) }
  end
  return times.max
end
