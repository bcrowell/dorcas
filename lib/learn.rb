# coding: utf-8

def learn_pats(job,page,report_dir,temp_dir)
  if job.no_matching then
    pats = create_pats_no_matching(job,page)
  else
    pats = match_characters_to_image(job,page,report_dir,temp_dir)
  end
  return pats
end

def match_characters_to_image(job,page,report_dir,temp_dir)
  all_fonts,script_and_case_to_font_name = load_fonts(job)

  pats = []
  job.characters.each { |x|
    # x looks like ["greek","lowercase","αβγδε"]. The string of characters at the end has already been filled in by initializer, if necessary.
    script_name,c,chars = x 
    font_name = script_and_case_to_font_name["#{script_name}***#{c}"]
    seed_font = all_fonts[font_name]
    script = Script.new(script_name)
    dpi = match_seed_font_scale(seed_font,page.stats,script,job.adjust_size)
    print "  #{script_name} #{c} #{chars} #{font_name} #{dpi.round} dpi\n"
    print "  metrics: #{seed_font.metrics(dpi,script)}\n"
    chars.chars.each { |char|
      force_cl = nil
      if (not job.prefer_cluster.nil?) and job.prefer_cluster.has_key?(char) then force_cl=job.prefer_cluster[char] end
      force_loc = nil
      if (not job.force_location.nil?) and job.force_location.has_key?(char) then force_loc=job.force_location[char] end
      name = char_to_short_name(char)
      matches_svg_file = dir_and_file_to_path(report_dir,"matches_#{name}.svg")
      pat,hits,composites = match_character(char,job,page,temp_dir,seed_font,dpi,script,report_dir,matches_svg_file,name,force_cl,force_loc)
      if not (pat.nil?) then pats.push([true,pat]) else pats.push([false,char]) end
    }
  }

  return pats

end

  # figure out from job object: text_file(=job.image), text, spacing_multiple, threshold, cluster_threshold, output_dir(=job.output), prev_set(=job.set)
  # fudge_size(=job.adjust_size), stats(=page.stats), peak_to_bg(=page....), dpi(=page...)

def match_character(char,job,page,temp_dir,seed_font,dpi,script,report_dir,matches_svg_file,name,force_cl,force_loc)
  verbosity = 2
  # returns nil if there's no match
  print "Searching for character #{char} in text file #{text_file}\n"
  pat_from_prev = false
  if !(job.set.nil?) then pat_from_prev=job.set.pat(char) end
  wmatch_character_messages_helper(pat_from_prev,force_cl,force_loc,verbosity)
  if pat_from_prev then
    pat = job.set.pat(char)
  else
    pat = char_to_pat(char,temp_dir,f,page.dpi,script,char)
  end
  if verbosity>=3 then print "pat.line_spacing=#{pat.line_spacing}, bbox=#{pat.bbox}\n" end

  max_hits = 30 # Performance is bad when the number of hits is very large.
  hits = match(text,pat,page.stats,threshold,force_loc,max_hits)
  # in git commit cda9ba6ff452a0b508 , file match.rb, function old_match()
  # Also see notes at top of Match class.
  composites = swatches(hits,page.image,pat,page.stats,char,job.cluster_threshold)
  # ... in match.rb
  if force_cl.nil? then
    composite = composites[0]
  else
    match_character_messages_helper2(verbosity,force_cl,composites,char)
    composite = composites[force_cl]
  end
  if composite.nil? then print "  no matches found for #{char}\n"; return end
  matches_as_svg(report_dir,matches_svg_file,char_name,job.image,page.image,pat,hits,composites)
  pat.transplant(composite)
  pat.save(Pat.char_to_filename(output_dir,char))
  return [pat,hits,composites]
end

def create_pats_no_matching(job,page)
  all_fonts,script_and_case_to_font_name = load_fonts(job)
  print "Not doing any matching, just rendering patterns for these characters from the seed font: #{job.characters}.\n"
  pats = []
  job.characters.each { |x|
    script_name,c,chars = x 
    font_name = script_and_case_to_font_name["#{script_name}***#{c}"]
    seed_font = all_fonts[font_name]
    script = Script.new(script_name)
    dpi = match_seed_font_scale(seed_font,stats,script,fudge_size)
    print "  #{script_name} #{c} #{chars} #{font_name} #{dpi.round} dpi, #{job.guess_font_size} pt\n"
    print "  metrics: #{seed_font.metrics(dpi,script)}\n"
    chars.chars.each { |char|
      print "    Rendering #{char}.\n"
      name = char_to_short_name(char)
      pat = char_to_pat(char,output_dir,seed_font,dpi,script,char)
      if pat.nil? then die("    ...nil result") end
      if not (pat.nil?) then pats.push([true,pat]) else pats.push([false,char]) end
      file = Pat.char_to_filename(output_dir,char)
      print "    ...Written to #{file}\n"
      pat.save(file)
    }
  }
  return pats
end

def load_fonts(job)
  # Tell them what seed fonts we understood them as requesting. If they gave a name that doesn't work, fontconfig will
  # fall back to something stupid. We try to detect that and warn them.
  # Build a hash all_fonts whose keys are the user-supplied strings and whose values are Font objects.
  all_fonts = {}
  script_and_case_to_font_name = {}
  print "Fonts:\n"
  job.seed_fonts.each { |x|
    s = x[0] # may be a font name or a ttf filename
    script_and_case_to_font_name["#{x[1]}***#{x[2]}"] = s # key is like greek***lowercase
    file = Job.font_string_to_path(s)
    if Job.font_string_is_full_path(s) then
      print "  #{s}\n"
    else
      print "  #{s} -> #{file}\n"
      round_trip = Fontconfig.path_to_name(file)
      if round_trip!=s then
        warn("In #{job_file}, the font name '#{s}' does not match the name '#{round_trip}' of the file supplied by fontconfig.\n"+
               "This probably means either that you don't have the font on your system or that you gave the wrong name or a different form of the name.")
      end
    end
    if not (all_fonts.has_key?(s)) then
      all_fonts[s] = Font.new(file_path:file)
    end
  }
  return [all_fonts,script_and_case_to_font_name]
end

def create_directories(output_dir,report_dir)
  temp_dir = 'temp'
  if File.exists?(output_dir) then FileUtils.rm_rf(output_dir) end # has safety features, https://stackoverflow.com/a/12335711
  if not File.exists?(temp_dir) then Dir.mkdir(temp_dir) end
  if not File.exists?(output_dir) then Dir.mkdir(output_dir) end
  if not File.exists?(report_dir) then Dir.mkdir(report_dir) end
  return [temp_dir,output_dir]
end

def copy_all_pat_files(set,output_dir)
  # First look for files that exist in the output directory but not the input.
  # Silently allowing this could lead to very confusing stuff happening.
  Dir[dir_and_file_to_path(output_dir,"*.pat")].each { |filename|
    name = File.basename(filename)
    name =~ /(.*)\.pat$/
    short_char_name = $1
    if not set.has_pat?(short_char_name) then FileUtils.rm_f(filename) end
  }
  # Now copy from input to output.
  set.all_char_names.each { |char_name|
    name = char_name+".pat"
    destination = dir_and_file_to_path(output_dir,name)
    set.pat(char_name).save(destination)
  }
end

def match_character_messages_helper(pat_from_prev,force_cl,force_loc,verbosity)
  if pat_from_prev and not force_cl.nil? then
    warn("The pattern #{prev_pat_filename} exists for character #{char}, but prefer_cluster is set to #{force_cl+1}.\n"+
         "Typically this is a mistake, and the pattern file should have been deleted from the input directory.\n"+
         "Normally the prefer_cluster feature is used with the seed font, not with a previously constructed pattern.\n")
  end
  if pat_from_prev and not force_loc.nil? then
    warn("A pattern exists in the input pattern set for character #{char}, but force_loc is set to #{force_loc}.\n"+
         "Typically this is a mistake, and the pattern file should have been deleted from the input directory.\n"+
         "Normally the force_location feature is used with the seed font, not with a previously constructed pattern.\n")
  end
  if verbosity>=2 then
    if pat_from_prev then
      print "  Taking pattern from previous run\n"
    else
      print "  Generating new character from seed font.\n"
    end
  end
end

def match_character_messages_helper2(verbosity,force_cl,composites,char)
  if verbosity>=2 then print "  Forcing a match to cluster #{force_cl+1}.\n" end
  if force_cl<0 or force_cl>composites.length-1 then 
    die("illegal value in prefer_cluster, [\"#{char}\",#{force_cl+1}], only #{composites.length} clusters found")
  end
end

