def shotgun(job,text,stats,output_dir,report_dir,threshold:0.70,verbosity:2)
  
  if job.set.nil? then die("job file doesn't contain a set parameter specifying a pattern set") end
  set = Fset.from_file(job.set)

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
    print "  scanning for #{c}\n"
    pat = set.pat(c)
    max_hits = 1000
    hits = correl_convenience(text_ink,pat,stats,box,line_spacing,threshold,max_hits,verbosity:verbosity)
    # Returns a list of hits in the format [... [c,i,j,jb] ...], sorted in descending order by correlation score c.
    
    v = pat.visual(black_color:ChunkyPNG::Color::rgba(0,0,255,100),red_color:nil) # semitransparent blue
    hits.each { |x|
      c,i,j,jb = x
      print "    ",x,"\n"
      monitor_image = compose_safe(monitor_image,v,i,j)
      monitor_image.save(monitor_file)
    }
  }

  print "monitor file #{monitor_file} not being deleted for convenience ---\n" # qwe
  #FileUtils.rm_f(monitor_file)
end

