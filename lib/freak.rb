def freak(job,page,stats,output_dir,report_dir,xheight:30,verbosity:2,batch_code:'')
  # Pure frequency-domain analysis, using fft.
  # Text is a chunkypng object that was read using image_from_file_to_grayscale, and
  # stats are ink stats calculated from that, so the conversion to and from ink
  # units is the obvious, trivial one of multiplying or dividing by 255.
  # Xheight can come from seed_font.metrics(dpi,script)['xheight'], is used to estimate
  # parameters for peak detection kernel.
  # stats should contain keys 'background', 'dark', and 'threshold'

  text = page.image
  text_ink = page.ink

  est_max_chars = 0.3*text.width*text.height/(xheight*xheight)
  # ... The 0.3 was estimated from some sample text.
  est_max_freq = 0.13 # frequency of 'e' in English text, https://en.wikipedia.org/wiki/Letter_frequency
  est_max_one_char = est_max_freq*est_max_chars # estimated maximum number of occurrences of any character
  max_hits = (est_max_one_char*2).round # double the plausible number of occurrences
  #print "est_max_chars=#{est_max_chars}, est_max_freq=#{est_max_freq}, est_max_one_char=#{est_max_one_char}, max_hits=#{max_hits}\n"

  # The following should not be hardcoded, fixme.
  # Setting threshold1 very low incurs a big performance hit in peak detection and ends up bringing back only a few more
  # mathches  that would make it through later stages.
  # Setting threshold1:
  #   Comparing values of 0.0 and 0.2, the latter cut about half the matches while getting rid of only 1 of 51 hits later judged good.
  #   At 0.2, we get about 18% real matches, the rest false positives.
  # Setting threshold2:
  #   When other thresholds are set to reasonable values (t1=0.2, t3=0.0), setting t2 to any value less <=0.5 doesn't
  #   get rid of any matches. Setting it to 0.7 gives about 1/3 false negatives. Setting it fairly high gives me more
  #   room to make the final matching algorithm more cpu-intensive.
  # Setting threshold3:
  #   If you leave the earlier stages wide open (threshold1=-1, max_hits very high), then setting
  #   threshold3=-0.2 gives many obviously bad matches, 0 gives only a few false positives. If early stages are
  #   set much tighter, then threshold3 can be set as low as -0.5 with very few false positives.
  threshold1,threshold2,threshold3 = [0.2,0.4,0.0]
  smear = 2 # used in Pat.fix_red()

  # parameters for gaussian cross peak detection:
  sigma = xheight/10.0 # gives 3 for Giles, which seemed to work pretty well; varying sigma mainly just renormalizes scores
  a = (xheight/3.0).round # gives 10 for Giles; reducing it by a factor of 2 breaks peak detection; doubling it has little effect

  if job.set.nil? then die("job file doesn't contain a set parameter specifying a pattern set") end
  set = Fset.from_file_or_directory(job.set)

  if true then
    monitor_file = temp_file_name_short(prefix:"mon")+".png"
    monitor_file = "mon.png"; print "---- using deterministic name mon.png for convenience, won't work with parallelism ---\n"
    monitor_image = text.clone.grayscale
    monitor_image.save(monitor_file)
    print "monitor file: #{monitor_file} (can be viewed live using okular)\n"
    # ...  https://unix.stackexchange.com/questions/167808/image-viewer-with-auto-reload-on-file-change
  end

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

  all_chars = ''
  files_to_delete = []
  all_codes = []

  #['αααααααααααααα'].each { |chars|
  #['αααααααααααααα','ββββββββββββββ','γγγγγγγγγγγγγγγγ','δδδδδδδδδδδδδδδδδ'].each { |chars|
  ['αβ','γδ','εζ','ηθ'].each { |chars|
    all_chars = all_chars+chars
    pats = chars.chars.map{ |c| set.pat(c) }
    char_names = chars.chars.map { |c| char_to_short_name(c) }
    code,killem = freak_generate_code_and_prep_files(outfile,batch_code,text,pats,a,sigma,image_ampl,image_bg,image_thr,high_pass,char_names,
           threshold1,max_hits)
    files_to_delete.concat(killem)
    all_codes.push(code)
  }

  #print code

  # run it
  hits = convolve(all_codes,[outfile],batch_code)

  bw = {}
  red = {}
  sdp = {}
  pat_by_name = {}
  all_chars.chars.each { |c|
    n = char_to_short_name(c)
    p = set.pat(c)
    pat_by_name[n] = p
    bw[n] = image_to_ink_array(p.bw)
    red[n] = image_to_ink_array(p.red)
    pat_stats = ink_stats_pat(bw[n],red[n]) # calculates mean and sd
    sdp[n] = pat_stats['sd']
  }

  foo = pat_by_name['epsilon']
  Pat.fix_red(foo.red,foo.baseline)

  make_scatterplot = false

  hits2 = []
  bg = stats['background']
  if make_scatterplot then scatt=[] end
  hits.each { |x|
    co1,i,j,misc = x
    short_name = misc['label']
    norm = sdp[short_name]*stats['sd_in_text']
    co2 = correl(text_ink,bw[short_name],red[short_name],bg,i,j,norm)
    debug=nil
    co3,garbage = squirrel(text_ink,bw[short_name],red[short_name],i,j,stats,smear:smear,debug:debug)
    if make_scatterplot then scatt.push([co1,co3]) end
    #if co2>0.0 then print "i,j=#{i} #{j} raw=#{co1}, co2=#{co2}, co3=#{co3}\n" end
    if co2<threshold2 then next end
    if co3<threshold3 then next end
    hits2.push(x)
  }
  print "filtered #{hits.length} to #{hits2.length}\n"
  hits = hits2

  png_report(monitor_file,text,hits,all_chars,set,verbosity:2)
  if make_scatterplot then print ascii_scatterplot(hits,save_to_file:'scatt.txt') end
  print "hits written to #{outfile}\n"

  files_to_delete.each { |f|
    FileUtils.rm_f(f)
  }

  if true then
    print "monitor file #{monitor_file} not being deleted for convenience ---\n"
    #FileUtils.rm_f(monitor_file)
  end
end

def freak_generate_code_and_prep_files(outfile,batch_code,text,pats,a,sigma,image_ampl,image_bg,image_thr,high_pass,char_names,threshold1,
                       max_hits,parallelizable:false)
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
  # The parallelizable flag would be set to true if we were going to hypothetically do parallelization *inside* convolve.py.
  verbosity=3

  if a.class!=1.class then die("a is not an integer") end

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
  want_clipping = false
  want_filtering = !(high_pass.nil?)
  if want_filtering then  
    hpfx = (w.to_f/high_pass[0].to_f).round
    hpfy = (h.to_f/high_pass[1].to_f).round
  end

  k = 3.0 # changing this to 1.0 makes little difference, mainly just renormalizes scores
  nb_fudge = 0.3
  # ... Changing this to 0 or 0.4 just renormalizes scores; raising it to 1.0 requires vastly lowering threshold, gives terrible performance.

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
    code.push("d score_#{count}")
    if not parallelizable then code.push("forget #{name_space['b']},forget #{name_space['w']}") end # for memory efficiency
    if write_debugging_images then
      code.push("r score_#{count}")
      code.push("dup,u max,f 1,b max,f 255,swap,b /,s *,noneg") # normalize
      code.push("c score_#{char_names[count]}.png")
      code.push("write")
    end
    norm = 1.0/nb
    code.push("r score_#{count},f #{threshold1},i #{a},i #{max_hits},c #{outfile},c a,c #{char_names[count]},f #{norm},i #{text.width},i #{text.height},c #{batch_code},peaks")
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
