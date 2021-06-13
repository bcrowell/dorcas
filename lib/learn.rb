# coding: utf-8

def extract_matching_swatches(job,page,report_dir,verbosity:2)
  # Returns a hash whose keys are characters and whose values are of the form [hits,images].
  from_seed = job.set.nil?
  if from_seed then Fset.grow_from_seed(job,page) end
  if verbosity>=2 then
    if from_seed then
      print "  Generating new character from seed font.\n"
    else
      print "  Taking pattern from previous run\n"
    end
  end
  all_fonts,script_and_case_to_font_name = load_fonts(job)
  all_chars = job.characters.map {|x| x[2]}.inject('') {|all,these| all = all+these}
  match = Match.new(characters:all_chars,meta_threshold:job.threshold,force_loc:job.force_location)
  # ... force_loc not yet reimplemented
  match.batch_code = Process.pid.to_s
  match.three_stage_prep(page,job.set)

  results = {}
  job.characters.each { |x|
    # x looks like ["greek","lowercase","αβγδε"]. The string of characters at the end has already been filled in by initializer, if necessary.
    script_name,c,chars = x
    chars.chars.each { |char|
      force_cl = nil
      if (not job.prefer_cluster.nil?) and job.prefer_cluster.has_key?(char) then force_cl=job.prefer_cluster[char] end
      force_loc = nil
      if (not job.force_location.nil?) and job.force_location.has_key?(char) then force_loc=job.force_location[char] end
      name = char_to_short_name(char)
      matches_svg_file = dir_and_file_to_path(report_dir,"matches_#{name}.svg")
      script = Script.new(script_name)
      results[char] = match_character(match,char,job,page,script,report_dir,matches_svg_file,name,force_cl,from_seed)
    }
  }
  return results
end

def match_character(match,char,job,page,script,report_dir,matches_svg_file,name,force_cl,from_seed,verbosity:2)
  # Returns [hits,images].
  if !(page.dpi.nil?) and (page.dpi<=0 or page.dpi>2000) then die("page.dpi=#{page.dpi} fails sanity check") end
  print "Examining #{match.count_candidates(char)} candidates from FFT for character #{char}.\n"
  pat = job.set.pat(char)
  if verbosity>=3 then print "pat.line_spacing=#{pat.line_spacing}, bbox=#{pat.bbox}\n" end
  if job.set.nil? then die("job.set is nil") end

  hits = match.three_stage_finish(page,job.set,chars:char)
  match.three_stage_cleanup(page)
  # ...consider using squirrel only, esp. if using force_loc

  images = swatches(hits,page.image,pat,page.stats,char,job.cluster_threshold) # returns a list of chunkypng images
  char_name = char_to_short_name(char)
  return [hits,images]
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
    page.dpi = match_seed_font_scale(seed_font,page.stats,script,job.adjust_size)
    print "  #{script_name} #{c} #{chars} #{font_name} #{page.dpi} dpi, #{job.guess_font_size} pt\n"
    print "  metrics: #{seed_font.metrics(page.dpi,script)}\n"
    chars.chars.each { |char|
      print "    Rendering #{char}.\n"
      name = char_to_short_name(char)
      pat = char_to_pat(char,job.output,seed_font,page.dpi,script)
      if pat.nil? then die("    ...nil result") end
      if not (pat.nil?) then pats.push([true,pat]) else pats.push([false,char]) end
      file = Pat.char_to_filename(job.output,char)
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
  if File.exists?(output_dir) then FileUtils.rm_rf(output_dir) end # has safety features, https://stackoverflow.com/a/12335711
  if not File.exists?(output_dir) then Dir.mkdir(output_dir) end
  if not File.exists?(report_dir) then Dir.mkdir(report_dir) end
  return output_dir
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


