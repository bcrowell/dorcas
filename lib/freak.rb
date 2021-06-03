def freak(job,text,stats,output_dir,report_dir,xheight:30,threshold:0.60,verbosity:2)
  # Pure frequency-domain analysis, using fft.
  # Text is a chunkypng object that was read using image_from_file_to_grayscale, and
  # stats are ink stats calculated from that, so the conversion to and from ink
  # units is the obvious, trivial one of multiplying or dividing by 255.
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

  ink_array_to_image(image_to_ink_array(text))

  chars = 'ερ'
  pats = chars.chars.map{ |c| set.pat(c) }

  # parameters for gaussian cross peak detection:
  sigma = xheight/10.0 # gives 3 for Giles, which seemed to work pretty well
  a = (xheight/3.0).round # gives 10 for Giles

  # Input image stats are all in ink units. See comments at top of function about why it's OK
  # to apply the trivial conversion to PNG grayscale. The output of ink_to_png_8bit_grayscale()
  # is defined so that black is 0.
  image_bg = ink_to_png_8bit_grayscale(stats['background'])
  image_ampl = ink_to_png_8bit_grayscale(stats['dark']-stats['background']) # positive
  image_thr = ink_to_png_8bit_grayscale(stats['threshold'])
  print "image_bg,image_ampl,image_thr = #{[image_bg,image_ampl,image_thr]}\n"

  # high-pass filter to get rid of any modulation of background; x period and y period
  high_pass = [10*xheight,10*xheight]

  code = freak_generate_code(text,pats,a,sigma,image_ampl,image_bg,image_thr,high_pass)

  print code

  if false then
    print "monitor file #{monitor_file} not being deleted for convenience ---\n" # qwe
    FileUtils.rm_f(monitor_file)
  end
end

def freak_generate_code(text,pats,a,sigma,image_ampl,image_bg,image_thr,high_pass)
  # image_ampl,image_bg, and image_thr are all positive ints with black=0
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

  #-----------

  code.push("i #{w},d w,i #{h},d h")
  code.push("i #{high_pass[0]},d high_pass_x,i #{high_pass[1]},d high_pass_y")
  code.push("i #{a},d a,f #{sigma},d sigma")

  # kernel for peak detection
  code.push("r a,r sigma,gaussian_cross_kernel")
  code.push("r w,r h,f 0.0,bloat")
  code.push("fft")
  code.push("d kernel_f_domain")

  # ship out the image of the text, generate code to read it in and do prep work
  freak_prep_image(text,image_file) unless skip_file_prep
  code.concat(freak_gen_get_image('signal_f_domain_unfiltered',image_file,image_bg,image_ampl,w,h))
  code.push("r signal_f_domain_unfiltered,r high_pass_x,r high_pass_y,high_pass,d signal_f_domain")

  # ship out the black and white masks for the characters, generate code to read in and prepare
  count = 0
  pats.each { |pat|
    ['b','w'].each { |t|
      if t=='b' then im=pat.bw else im=pat.white end
      temp_file = temp_file_name()
      files_to_delete.push(temp_file)
      freak_prep_image(im,temp_file) unless skip_file_prep
      code.concat(freak_gen_get_image("#{t}#{count}_f_domain",temp_file,255,255,w,h,rot:true))
    }
    count = count+1
  }


  code.push("r ")

  #-----------

  # postprocess code

  code = code.map { |x| x.gsub(/,/,"\n") }.join("\n")+"\n"

  files_to_delete.each { |f|
    FileUtils.rm_f(f)
  }

  return code
end

def freak_prep_image(im,file)
  # im is a chunkypng object
  im.save(file)
end

def freak_gen_get_image(label,filename,image_bg,image_ampl,w,h,rot:false)
  # image_ampl and image_bg are positive ints with black=0.
  # Image read from file will be non-inverse video.
  # Transform pixel values like y=ax+b.
  a = -1.0/image_ampl.to_f
  b = image_bg.to_f/image_ampl.to_f
  code = []
  code.push("c #{filename}") # do as a separate element in case of commas in filename
  if rot then code.push("read_rot") else code.push("read") end
  code.push("f #{a},s *,f #{b},s +") # invert video, background=0, ink=1
  code.push("r w,r h,f 0.0,bloat")
  code.push("u fft")
  code.push("d #{label}")
  return code
end
