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

  chars = 'ε'
  pats = chars.chars.map{ |c| set.pat(c) }
  char_names = chars.chars.map { |c| char_to_short_name(c) }

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

  code,files_to_delete = freak_generate_code_and_prep_files(text,pats,a,sigma,image_ampl,image_bg,image_thr,high_pass,char_names)

  print code

  # run it
  convolve2(code,human_input:false)

  files_to_delete.each { |f|
    FileUtils.rm_f(f)
  }

  if false then
    print "monitor file #{monitor_file} not being deleted for convenience ---\n" # qwe
    FileUtils.rm_f(monitor_file)
  end
end

def freak_generate_code_and_prep_files(text,pats,a,sigma,image_ampl,image_bg,image_thr,high_pass,char_names,parallelizable:false)
  # image_ampl,image_bg, and image_thr are all positive ints with black=0
  # char_names is used only for things like picking readable names for debugging files
  files_to_delete = []
  image_file = temp_file_name()
  files_to_delete.push(image_file)
  code = []

  skip_file_prep = false # if true, then for testing of code generation, don't bother writing and deleting files
  write_debugging_images = true

  pat_widths = []
  pat_heights = []
  pats.each { |pat|
    pat_widths.push(pat.width)
    pat_heights.push(pat.height)
    #print "... #{pat.width}, #{pat.height}\n"
  }
  max_pat_width = pat_widths.max
  max_pat_height = pat_heights.max

  #print "text.width=#{text.width}, max_pat_width=#{max_pat_width}, a=#{a}, #{text.width+max_pat_width+2*a+1}\n"
  w = boost_for_no_large_prime_factors(text.width+max_pat_width+2*a+1)
  h = boost_for_no_large_prime_factors(text.height+max_pat_height+2*a+1)

  hpfx = (w.to_f/high_pass[0].to_f).round
  hpfy = (h.to_f/high_pass[1].to_f).round

  k = 3.0
  # score = (signal & b) - k (signal & w) - k (! signal) & b
  # score/k = -N_b + Sum [ (1+1/k) (signal & b) - (signal & w) ]
  #         = -N_b + signal convolved with [ (1+1/k) b - w ]
  # where N_b = number of black bits in the pattern.
  # We calculate this by convolution, on a scale where false=0, true=255.

  #-----------

  if not parallelizable then
    code.push("i 0,d strict_fp") # allow mutation of the symbol table, so I can free up the memory used by images as I go
  end
  code.push("i #{w},d w,i #{h},d h")
  code.push("i #{hpfx},d high_pass_x,i #{hpfy},d high_pass_y")
  code.push("i #{a},d a,f #{sigma},d sigma")

  # kernel for peak detection
  code.push("r w,r h,r a,r sigma,gaussian_cross_kernel")
  code.push("r w,r h,f 0.0,bloat")
  code.push("u fft")
  code.push("d kernel_f_domain")

  # ship out the image of the text, generate code to read it in and do prep work
  freak_prep_image(text,image_file) unless skip_file_prep
  code.concat(freak_gen_get_image('signal_space_domain_unfiltered',image_file,image_bg,image_ampl,w,h))
  code.push("r signal_space_domain_unfiltered,u fft,r high_pass_x,r high_pass_y,high_pass,d signal_f_domain")

  count = 0
  pats.each { |pat|
    name_space = {}
    nb = nil
    ['b','w'].each { |t|
      name_space[t] = "space_#{t}#{count}"
      if t=='b' then im=pat.bw else im=pat.white end
      if t=='b' then nb=n_black_pixels(pat.bw) end
      # ship out the black and white masks for the character
      temp_file = temp_file_name()
      files_to_delete.push(temp_file)
      freak_prep_image(im,temp_file) unless skip_file_prep
      # generate code to read in and prepare
      code.concat(freak_gen_get_image("#{name_space[t]}",temp_file,255,255,w,h,rot:true))
      # generate code to analyze it
    }
    if nb.nil? then die("nb nil") end
    code.push("r #{name_space['b']},f #{1.0+1.0/k},s *")
    code.push("r #{name_space['w']}")
    code.push("a -") # linear combination of black and white convolutions
    code.push("f #{-nb},s +") # constant term; image has already been normalized so dark ink is N=1, otherwise we'd need to multiply by N^2 here
    code.push("u fft") # combined template in frequency domain
    code.push("r signal_f_domain")
    code.push("r kernel_f_domain")
    code.push("a *,a *,u ifft,noneg")
    code.push("d score_#{count}")
    if not parallelizable then code.push("forget #{name_space['b']},forget #{name_space['w']}") end # for memory efficiency
    if write_debugging_images then
      code.push("r score_#{count}")
      code.push("dup,u max,f 1,b max,f 255,swap,b /,s *") # normalize
      code.push("c score_#{char_names[count]}.png")
      code.push("write")
    end
    count = count+1
  }

  #-----------

  # postprocess code
  code = code.map { |x| x.gsub(/,/,"\n") }.join("\n")+"\n"

  return [code,files_to_delete]
end

def freak_prep_image(im,file)
  # im is a chunkypng object
  im.save(file)
end

def freak_gen_get_image(label,filename,image_bg,image_ampl,w,h,rot:false,debug:nil)
  # image_ampl and image_bg are positive ints with black=0.
  # Image read from file will be non-inverse video.
  # Transform pixel values like y=ax+b.
  a = -1.0/image_ampl.to_f
  b = image_bg.to_f/image_ampl.to_f
  code = []
  code.push("c #{filename}") # do as a separate element in case of commas in filename
  if rot then code.push("read_rot") else code.push("read") end
  code.push("f #{a},s *,f #{b},s +") # invert video, background=0, ink=1
  if rot then bloat_op='bloat_rot' else bloat_op='bloat' end
  code.push("r w,r h,f 0.0,#{bloat_op}")
  code.push("d #{label}")
  return code
end
