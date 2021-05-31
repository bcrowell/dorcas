def shotgun(job,text,stats,output_dir,report_dir,threshold:0.60,verbosity:2)
  
  if job.set.nil? then die("job file doesn't contain a set parameter specifying a pattern set") end
  set = Fset.from_file_or_directory(job.set)

  dpi = job.guess_dpi
  line_spacing = metrics_to_estimated_line_spacing(dpi,set.size,spacing_multiple:1)
  text_ink = image_to_ink_array(text)
  box = Box.from_image(text)

  monitor_file = temp_file_name_short(prefix:"mon")+".png"
  monitor_file = "mon.png"; print "---- using deterministic name mon.png for convenience, won't work with parallelism ---\n" # qwe
  monitor_image = text.clone.grayscale
  monitor_image.save(monitor_file)
  print "monitor file: #{monitor_file} (can be viewed live using okular)\n"
  # ...  https://unix.stackexchange.com/questions/167808/image-viewer-with-auto-reload-on-file-change

  Script.new('greek').alphabet(c:"lowercase").chars.each { |c|
  #'ρ'.chars.each { |c|
    print "  scanning for #{c}\n"
    pat = set.pat(c)
    max_hits = 1000
    hits,details = correl_convenience(text_ink,pat,stats,box,line_spacing,threshold,max_hits,verbosity:verbosity,
                 give_details:true,heat:true,
                 implementation:'chapel'
    )
    # Returns a list of hits in the format [... [c,i,j,jb] ...], sorted in descending order by correlation score c.

    heat = details['heat']
    a,b=1.0,0.0
    transform_array_elements_linearly!(heat,a,b,0.0,1.0)
    image = ink_array_to_image(heat,transpose:true)
    image.save("heat.png")
    
    v = pat.visual(black_color:ChunkyPNG::Color::rgba(255,0,0,130),red_color:nil) # semitransparent red
    hits.each { |x|
      c,i,j,jb = x
      if verbosity>=3 then print "    ",x,"\n" end
      monitor_image = compose_safe(monitor_image,v,i,j)
      monitor_image.save(monitor_file)
    }
  }

  print "monitor file #{monitor_file} not being deleted for convenience ---\n" # qwe
  #FileUtils.rm_f(monitor_file)
end

