def run_r_code(code)
  # if there is a line in the output containing the text __output__ followed by more stuff, then that stuff is
  file = temp_file_name()
  File.open(file,'w') { |f|
    f.print code
  }
  #print "file is #{file}\n"
  output = `R --quiet --slave --no-save --no-restore-data <#{file}`
  if $?!=0 then die("error running R code in file #{file} -- file has been preserved") end
  FileUtils.remove_dir(file)
  output =~ /__output__(.*)/
  return $1
end
