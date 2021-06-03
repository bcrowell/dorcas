def freak(job,text,stats,output_dir,report_dir,xheight:30,threshold:0.60,verbosity:2)
  # Pure frequency-domain analysis, using fft.
  # xheight can come from seed_font.metrics(dpi,script)['xheight']
  # stats should contain keys 'background', 'dark', and 'threshold'
  
  if job.set.nil? then die("job file doesn't contain a set parameter specifying a pattern set") end
  set = Fset.from_file_or_directory(job.set)

  if false then
    monitor_file = temp_file_name_short(prefix:"mon")+".png"
    monitor_file = "mon.png"; print "---- using deterministic name mon.png for convenience, won't work with parallelism ---\n" # qwe
    monitor_image = text.clone.grayscale
    monitor_image.save(monitor_file)
    print "monitor file: #{monitor_file} (can be viewed live using okular)\n"
    # ...  https://unix.stackexchange.com/questions/167808/image-viewer-with-auto-reload-on-file-change
  end

  chars = 'ερ'
  pats = chars.map{ |c| set.pat(c) }

  # parameters for gaussian cross peak detection:
  sigma = x_height/10.0 # gives 3 for Giles, which seemed to work pretty well
  a = round(x_height/3.0) # gives 10 for Giles

  # image stats, all in ink units
  image_bg = stats['background']
  image_ampl = stats['dark']-stats['background'] # in ink units
  image_thr = stats['threshold']

  # high-pass filter to get rid of any modulation of background; x period and y period
  high_pass = [10*x_height,10*x_height]

  code = freak_generate_code(pats,a,sigma,image_ampl,image_bg,image_thr,high_pass)

  if false then
    print "monitor file #{monitor_file} not being deleted for convenience ---\n" # qwe
    FileUtils.rm_f(monitor_file)
  end
end

def freak_generate_code(text,pats,a,sigma,image_ampl,image_bg,image_thr,high_pass)
  files_to_delete = []
  image_file = temp_file_name()
  files_to_delete.push(image_file)
  code = []

  skip_file_prep = true # for testing of code generation, don't bother writing and deleting files

  pat_widths = []
  pat_heights = []
  pats.each { |pat|
    pat_widths.push(pat.width)
    pat_heights.push(pat.height)
  }
  max_pat_width = pat_widths.max
  max_pat_height = pat_heights.max

  w = boost_for_no_large_prime_factors(text.width+max_pat_width+2*a+1)
  h = boost_for_no_large_prime_factors(text.height+max_pat_height+2*a+1)

  code.push("i #{w},d w,i #{h},d h")

  # ship out the image of the text
  freak_prep_image(text,image_file) unless skip_file_prep
  code.concat(freak_gen_get_image('signal',image_file,image_bg,image_ampl,w,h))

  # ship out the black and white masks for the characters
  count = 0
  pats.each { |pat|
    ['b','w'].each { |t|
      if t=='b' then im=pat.bw else im=pat.white end
      temp_file = temp_file_name()
      files_to_delete.push(temp_file)
      freak_prep_image(im,temp_file) unless skip_file_prep
      code.concat(freak_gen_get_image("#{t}#{count}",temp_file,0.0,1.0,w,h))
      count = count+1
    }
  }

  code = code.map { |x| x.gsub(/,/,"\n"}.join("\n")

  files_to_delete.each { |f|
    FileUtils.rm_f(f)
  }

  return code
end

def freak_prep_image(im,file)
  # im is a chunkypng object
  im.save(file)
end

freak_gen_get_image(label,filename,ink_bg,ink_ampl,w,h)
  code = []
  code.push("c #{filename}") # do as a separate element in case of commas in filename
  code.push("read")
  code.push("f -1,s *,f #{ink_bg}, s +") # invert video
  code.push("f #{1.0/ink_ampl},s *") # normalize
  code.push("r w,r h,f 0.0,bloat")
  code.push("fft")
  code.push("d #{label}")
  return code
end
