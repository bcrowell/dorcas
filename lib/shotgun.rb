def shotgun(job,text,stats,output_dir,report_dir,threshold,verbosity:2)
  
  if job.set.nil? then die("job file doesn't contain a set parameter specifying a pattern set") end
  set = Fset.from_file(job.set)

  dpi = job.guess_dpi
  line_spacing = metrics_to_estimated_line_spacing(dpi,set.size,spacing_multiple:1)
  text_ink = image_to_ink_array(text)
  box = Box.from_image(text)

  monitor_file = temp_file_name_short(prefix:"mon")+".png"
  monitor_image = text.clone.grayscale
  monitor_image.save(monitor_file)
  print "monitor file: #{monitor_file} (can be viewed live using eog)\n"
  # ...  https://unix.stackexchange.com/questions/167808/image-viewer-with-auto-reload-on-file-change

  'ε'.chars.each { |c|
    pat = set.pat(c)
    max_hits = 1000
    hits = correl_convenience(text_ink,pat,stats,box,line_spacing,threshold,max_hits,verbosity:verbosity)
    # Returns a list of hits in the format [... [c,i,j,jb] ...], sorted in descending order by correlation score c.
    
    v = pat.visual
    hits.each { |x|
      c,i,j = x
      print x,"\n"
    }
  }

  FileUtils.rm_f(monitor_file)
end

