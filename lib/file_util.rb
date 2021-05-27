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

def dir_and_file_to_path(dir,file)
  return dir+"/"+file # bug: won't work on windows
end

def create_text_file(filename,text)
  File.open(filename,'w') { |f|
    f.print text
  }
end
