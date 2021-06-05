def freak(job,text,stats,output_dir,report_dir,xheight:30,threshold:0.60,verbosity:2,batch_code:'')
  # Pure frequency-domain analysis, using fft.
  # Text is a chunkypng object that was read using image_from_file_to_grayscale, and
  # stats are ink stats calculated from that, so the conversion to and from ink
  # units is the obvious, trivial one of multiplying or dividing by 255.
  # Xheight can come from seed_font.metrics(dpi,script)['xheight'], is used to estimate
  # parameters for peak detection kernel.
  # stats should contain keys 'background', 'dark', and 'threshold'
  
  if job.set.nil? then die("job file doesn't contain a set parameter specifying a pattern set") end
  set = Fset.from_file_or_directory(job.set)

  if false then
    monitor_file = temp_file_name_short(prefix:"mon")+".png"
    monitor_file = "mon.png"; print "---- using deterministic name mon.png for convenience, won't work with parallelism ---\n"
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
  image_ampl = ink_to_png_8bit_grayscale(stats['background'])-ink_to_png_8bit_grayscale(stats['dark']) # positive
  image_thr = ink_to_png_8bit_grayscale(stats['threshold'])
  print "image_bg,image_ampl,image_thr = #{[image_bg,image_ampl,image_thr]}\n"

  # Convolve allows a high-pass filter to get rid of any modulation of background.
  # But this is not really needed when using the peak detection kernel, which makes the results
  # insensitive to a DC or slowly varying background.
  #high_pass = [10*xheight,10*xheight] # x period and y period
  high_pass = nil

  outfile = 'peaks.txt' # gets appended to; each hit is marked by batch code and character's label

  code,files_to_delete = freak_generate_code_and_prep_files(outfile,batch_code,text,pats,a,sigma,image_ampl,image_bg,image_thr,high_pass,char_names)

  #print code

  # run it
  hits = convolve(code,human_input:false,batch_code:batch_code,retrieve_hits_from_file:outfile)

  print "hits=#{hits}\n"

  files_to_delete.each { |f|
    FileUtils.rm_f(f)
  }

  if false then
    print "monitor file #{monitor_file} not being deleted for convenience ---\n"
    FileUtils.rm_f(monitor_file)
  end
end

def freak_generate_code_and_prep_files(outfile,batch_code,text,pats,a,sigma,image_ampl,image_bg,image_thr,high_pass,char_names,parallelizable:false)
  # Image_ampl,image_bg, and image_thr are all positive ints with black=0. Image_ampl is used to normalize the data, so that
  # scores are easy to interpret. Image_bg is subtracted out, although this shouldn't matter if the peak-detection kernel is
  # correctly getting rid of DC. Ink darker than image_ampl is clipped, and negative values are also clipped.
  # The result of all this is to make the signal approximately go from 0.0 (background) to 1.0 (ink). For a character that
  # has ink not as dark as the estimate (faded text, etc.), the highest value will be less than 1.0, and that will affect
  # scores proportionately.
  # Image_thr could be used to binary-ize the data, but I'm currently not doing that. It could have the advantage of making the
  # algorithm treat faint or faded ink the same as full-darkness ink, but it could have the disadvantage of misbehaving if
  # the image parameters were estimated incorrectly.
  # Char_names is used only for things like picking readable names for debugging files.
  # If you don't want high-pass filtering, supply nil for this input.
  verbosity=3

  files_to_delete = []
  image_file = temp_file_name()
  files_to_delete.push(image_file)
  code = []

  skip_file_prep = false # if true, then for testing of code generation, don't bother writing and deleting files

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

  write_debugging_images = true
  peak_detection_threshold = 0.001
  max_hits = 10
  want_clipping = false
  want_filtering = !(high_pass.nil?)
  if want_filtering then  
    hpfx = (w.to_f/high_pass[0].to_f).round
    hpfy = (h.to_f/high_pass[1].to_f).round
  end

  k = 3.0
  nb_fudge = 0.3
  # Do a scoring algorithm that worked well for me before when coded naively:
  #   S0 = Sum [ (signal & b) - k (signal & w) - k (! signal) & b ]
  # This is a boolean sliding window. It can be done more efficiently in frequency domain.
  # The idea is that an "and" is just a convolution, while a "not" is 1-x, which just produces an additional constant term.
  # S0/k = -N_bf + Sum [ (1+1/k) (signal & b) - (signal & w) ]
  #      = -N_bf + signal convolved with [ (1+1/k) b - w ]
  # where N_b = number of black bits in the template and f is a fudge factor described below.
  # We calculate this by convolution, on a hybrid analog-binary scale where false=0, true=1.0.
  # What is returned by this algorithm is S=S0/kNb.
  # For an input signal that's constrained to the range from 0 to 1, the maximum value of S is 1.
  # Theoretically the fudge factor f, which is set as the variable nb_fudge, should just be 1.
  # But that's for perfectly clean data and perfect matches. In reality, setting f=1 causes many
  # peaks of interest to become negative. This is awkward, for example, for visualization, and
  # in fact we always discard negative scores.

  #-----------

  if not parallelizable then
    code.push("i 0,d strict_fp") # allow mutation of the symbol table, so I can free up the memory used by images as I go
  end
  code.push("i #{w},d w,i #{h},d h")
  if want_filtering then code.push("i #{hpfx},d high_pass_x,i #{hpfy},d high_pass_y") end
  code.push("i #{a},d a,f #{sigma},d sigma")

  # kernel for peak detection
  code.push("r w,r h,r a,r sigma,gaussian_cross_kernel")
  code.push("r w,r h,f 0.0,bloat")
  code.push("u fft")
  code.push("d kernel_f_domain")

  # ship out the image of the text, generate code to read it in and do prep work
  freak_prep_image(text,image_file) unless skip_file_prep
  code.concat(freak_gen_get_image('signal_space_domain_unfiltered',image_file,image_bg,image_ampl,w,h))
  code.push("r signal_space_domain_unfiltered")
  if want_clipping then
    code.push("f 0.0,f 1.0,clip") # restrict values to the range from 0 to 1; otherwise dark ink could give bogus ultra-high scores
  end
  code.push("u fft")
  if want_filtering then code.push("r high_pass_x,r high_pass_y,high_pass") end
  code.push("d signal_f_domain")

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
    if verbosity>=3 then print "Nb=#{nb} for #{char_names[count]}\n" end
    code.push("r #{name_space['b']},f #{1.0+1.0/k},s *")
    code.push("r #{name_space['w']}")
    code.push("a -") # linear combination of black and white templates
    code.push("u fft") # combined template in frequency domain
    code.push("r signal_f_domain")
    code.push("r kernel_f_domain")
    code.push("a *,a *,u ifft")
    code.push("f #{-nb*nb_fudge},s +") # constant term; image has already been normalized so dark ink is N=1, otherwise we'd need to multiply by N^2 here
    code.push("noneg")
    code.push("d score_#{count}")
    if not parallelizable then code.push("forget #{name_space['b']},forget #{name_space['w']}") end # for memory efficiency
    if write_debugging_images then
      code.push("r score_#{count}")
      code.push("dup,u max,f 1,b max,f 255,swap,b /,s *") # normalize
      code.push("c score_#{char_names[count]}.png")
      code.push("write")
    end
    norm = 1.0/nb
    code.push("r score_#{count},f #{peak_detection_threshold},i #{a},i #{max_hits},c #{outfile},c a,c #{char_names[count]},f #{norm},i #{text.width},i #{text.height},c #{batch_code},peaks")
    # peaks_op(array,threshold,radius,max_peaks,filename,mode)
    count = count+1
  }

  #-----------

  # postprocess code
  code = code.map { |x| x.gsub(/,/,"\n") }.join("\n")+"\n"

  #print code

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
  if image_ampl<=0 then die("image_ampl<=0") end
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
