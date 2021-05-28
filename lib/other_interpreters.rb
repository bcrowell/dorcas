def shell_out(code)
  return run_interpreted_code(code,'shell')
end

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
  if language=='shell' then
    cmd1 = "sh"
    human_lang = 'sh'
    recognized = true
  end
  if language=='r' then
    cmd1 = "R --quiet --slave --no-save --no-restore-data"
    human_lang = 'R'
    recognized = true
  end
  if language=='perl' then
    cmd1 = "perl"
    human_lang = 'perl'
    recognized = true
  end
  if !recognized then die("unrecognized interpreter #{language}") end
  cmd = "#{cmd1} <#{file}"
  output = `#{cmd}`
  # ... In many cases, an error wold cause this to die with an exception. I could try to catch that, but actually in most cases that
  #     exception causes output that is what I need to see anyway. Should clean up temp file in that case, though.
  if $?!=0 then die("error running #{human_lang} code in file #{file}, using command #{cmd1} -- file has been preserved") end
  FileUtils.rm_f(file)
  output =~ /__output__(.*)/
  #print "output=#{output}=, 1=#{$1}=\n"
  return $1
end

