# coding: utf-8
def verbing(argv)
  verb = argv[0]
  argv.shift # remove 1st element
  recognized = false
  if verb=='extract' then verb_extract(argv); recognized=true end
  if verb=='insert' then verb_insert(argv); recognized=true end
  if verb=='test' then verb_test(); recognized=true end
  if !recognized then die("unrecognized verb #{verb}") end
end

def verb_insert(args)
  if args.length==1 and args[0]=='help' then print "usage: dorcas insert old.set ρ bw.png new.set\n"; return end

  set_file,raw_char_name,widget,output = args
  print "set_file,raw_char_name,widget,output=#{[set_file,raw_char_name,widget,output]}\n"
  if not File.exists?(set_file) then die("input file #{set_file} does not exist") end
  if not File.exists?(widget) then die("input file #{widget} does not exist") end
  if raw_char_name.length==1 then char_name=char_to_short_name(raw_char_name) else char_name=raw_char_name end
  if short_name_to_long_name(char_name).nil? then die("not the short name of any character: #{char_name}") end
  legal_names = ["bw.png","red.png","data.json"]
  unless legal_names.include?(widget) then die("#{widget} is not one of the legal names: #{legal_names.join(' ')}") end
  set = Fset.from_file_or_directory(set_file)
  pat = set.pat(char_name)
  if pat.nil? then die("didn't find character #{char_name} in #{set_file}") end
  temp_file = temp_file_name()+".zip" # zip doesn't work right if the filename doesn't end in .zip
  pat.save(temp_file)
  stem = File.basename(temp_file)
  pat_filename = "#{char_name}.pat"

  # cp ok.png bw.png && zip a.zip bw.png && zipinfo a.zip | grep bw

  # fixme: should do this using the ruby interface, but I'm too lazy
  if_echo = false
  FileUtils.cp(set_file,output)
  shell_out("zip -d #{output} \"#{pat_filename}\"",echo:if_echo) # otherwise the rename creates two entries with the same name
  shell_out("zip #{temp_file} #{widget}",echo:if_echo) # temp_file is the Pat object
  shell_out("zip -j #{output} #{temp_file}",echo:if_echo) # inserts it under the name stem
  shell_out("printf \"@ #{stem}\\n@=#{pat_filename}\\n\" | zipnote -w #{output}",echo:if_echo) # https://serverfault.com/a/726257

  print "data inserted in #{set_file} from #{char_name}, #{widget}, and written to #{output}\n"

  FileUtils.rm_f(temp_file)
end

def verb_extract(args)
  if args.length==1 and args[0]=='help' then print "usage: dorcas extract old.set ρ bw.png\n"; return end

  set_file,raw_char_name,output = args
  print "set_file,raw_char_name,output=#{[set_file,raw_char_name,output]}\n"
  if not File.exists?(set_file) then die("input file #{set_file} does not exist") end
  if raw_char_name.length==1 then char_name=char_to_short_name(raw_char_name) else char_name=raw_char_name end
  if short_name_to_long_name(char_name).nil? then die("not the short name of any character: #{char_name}") end
  legal_names = ["bw.png","red.png","data.json"]
  unless legal_names.include?(output) then die("#{output} is not one of the legal names: #{legal_names.join(' ')}") end
  part = {"bw.png"=>0,"red.png"=>1,"data.json"=>2}[output]
  expected_name_in_archive = output
  set = Fset.from_file_or_directory(set_file)
  pat = set.pat(char_name)
  if pat.nil? then die("didn't find character #{char_name} in #{set_file}") end
  temp_file = temp_file_name()
  temp_file2 = temp_file_name()
  pat.save(temp_file)

  content = nil
  found = false
  Zip::File.open(temp_file) do |zipfile|
    zipfile.each do |entry|
      next unless entry.name==expected_name_in_archive
      found = true
      entry.extract(temp_file2)
      if part==0 or part==1 then
        content = image_from_file_to_grayscale(temp_file2)
      else
        content = JSON.parse(entry.get_input_stream.read)
      end
    end
  end

  if !found then die("file #{expected_name_in_archive} not found in pattern for #{char_name}") end
  if part==0 or part==1 then
    content.save(output)
  else
    create_text_file(output,content)
  end
  print "data extracted from #{set_file}, #{char_name} to #{output}\n"

  FileUtils.rm_f(temp_file)
  FileUtils.rm_f(temp_file2)
end
