def run_r_code(code)
  return run_interpreted_code(code,'r')
end

def run_perl_code(code)
  return run_interpreted_code(code,'perl')
end

def run_interpreted_code(code,language)
  # If there is a line in the output containing the text __output__ followed by more stuff, then that stuff is returned.
  file = temp_file_name()
  File.open(file,'w') { |f|
    f.print code
  }
  #print "file is #{file}\n"
  recognized = false
  if language=='r' then
    output = `R --quiet --slave --no-save --no-restore-data <#{file}`
    human_lang = 'R'
    recognized = true
  end
  if language=='perl' then
    output = `perl <#{file}`
    human_lang = 'perl'
    recognized = true
  end
  if !recognized then die("unrecognized interpreterL #{language}") end
  if $?!=0 then die("error running #{human_lang} code in file #{file} -- file has been preserved") end
  FileUtils.remove_dir(file)
  output =~ /__output__(.*)/
  #print "output=#{output}=, 1=#{$1}=\n"
  return $1
end

