def verbing(argv)
  verb = argv[0]
  argv.shift # remove 1st element
  recognized = false
  if verb=='extract' then verb_extract(argv); recognized=true end
  if !recognized then die("unrecognized verb #{verb}") end
end

verb_extract(args)
  set_file,raw_char_name,part_name,output = args
  print "set_file,raw_char_name,part_name,output=#{[set_file,raw_char_name,part_name,output]}\n"
  if not File.exists?(set_file) then die("input file #{set_file} does not exist") end
  if raw_char_name.length==1 then char_name=char_to_short_name(raw_char_name) else char_name=raw_char_name end
  if short_name_to_long_name(char_name).nil? then die("not the short name of any character: #{char_name}") end
  part = {"bw"=>0,"red"=>1,"data"=>2}[part_name]
  if part.nil? then die("illegal part #{part_name}, must be bw, red, or data") end
  expected_name_in_archive = ["bw.png","red.png","data.json"][part]
  set = Fset.from_file(set_file)
  pat = set.pat(char_name)
  temp_file = temp_file_name()
  temp_file2 = temp_file_name()
  pat.save(temp_file)

  found = false
  Zip::File.open(temp_file) do |zipfile|
    zipfile.each do |entry|
      next unless entry.name==expected_name_in_archive
      found = true
      entry.extract(temp_file2)
      if part==0 or part==1 then
        content = ChunkyPNG::Image.from_file(temp)
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
  print "data extracted from #{set_file}, #{char_name}, #{expected_name_in_archive} to #{output}\n"

  FileUtils.rm_f(temp_file)
end
