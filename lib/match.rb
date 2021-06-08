# coding: utf-8

class Match
  # Describes a plan of attack for OCRing text. Includes thresholds, a list of characters to be matched, and
  # options such as forcing a character to be matched near a certain location on the page.
  # Forcing location is not yet implemented.
  # Meta_threshold is meant to go from 0 to 1. See tuning.rb for details.
  # Simplest use is through m=Match.new(), hits=m.execute().
  # Instead of m.execute, can also do m.three_stage_prep, m.three_stage_finish, ..., m.three_stage_cleanup, which
  # allows the fft stage to be parallelized while the characters are processed one at a time in m.three_stage_finish.
  def initialize(scripts:nil,characters:nil,meta_threshold:0.5,force_loc:nil)
    # Scripts is a list of script names or Script objects. Characters is a string containing the characters to be matched.
    # Either or both can be left to be set by default.
    if scripts.nil? then
      if characters.nil? then
        scripts = [Script.new('latin')]
      else
        scripts = characters.chars.map {|c| char_to_code_block(c)}.uniq.map {|s| Script.new(s)}
      end
    else
      scripts = scripts.map { |s| if s.kind_of?(Script) then s else Script.new(s) end}
    end
    @scripts = scripts
    if characters.nil? then
      characters = scripts.map { |s| s.alphabet(c:"both") }.inject('') {|s1,s2| s1+s2} # both upper and lower case in every script
    end
    @characters = characters
    @meta_threshold = meta_threshold
    if !(force_loc.nil?) then die("force_log not implemented") end
  end

  attr_reader :scripts,:characters
  attr_accessor :meta_threshold,:hits
  attr_accessor :pars,:monitor_file,:files_to_delete,:batch_code # private methods

  def execute(page,set,batch_code:'',if_monitor_file:true)
    # Three-stage matching consisting of freak, simple correlation, and squirrel.
    # Page must have .stats containing an 'x_height' key, which is used to estimate parameters for peak detection kernel and maximum number of hits.
    # Stats should also contain keys 'background', 'dark', and 'threshold'.

    self.batch_code = batch_code

    self.three_stage_prep(page,set,self.meta_threshold,if_monitor_file:if_monitor_file)
    self.hits = self.three_stage_finish(page,set)
    self.three_stage_cleanup(page)

    return self.hits
  end

  def three_stage_prep(page,set,meta_threshold,if_monitor_file:true)
    # This runs the first of the three stages, using fft convolution. This is the part that parallelizes well to multiple cores, and for
    # performance should be called with many characters at once in self.characters.
    # It stores all the hits from the first stage in self.hits, and these can
    # then be run through the later stages using three_stage_complete(), which can be called one character at a time if desired.
    die("stats= #{stats.keys}, does not contain the required stats") unless array_subset?(['x_height','background','dark','threshold'],page.stats.keys)
    die("set is nil") if set.nil?
    self.monitor_file=match_prep_monitor_file_helper(if_monitor_file,page)
    xheight = page.stats['x_height']
    self.pars = three_stage_guess_pars(page,xheight,meta_threshold:meta_threshold)
    threshold1,threshold2,threshold3,sigma,a,laxness,smear,max_hits = self.pars
    outfile = 'peaks.txt' # gets appended to; each hit is marked by batch code and character's label
    self.hits,self.files_to_delete = freak(page,self.characters,set,outfile,page.stats,threshold1,sigma,a,laxness,max_hits,batch_code:self.batch_code)
  end

  def three_stage_finish(page,set,chars:self.characters)
    # This can be called on one character at a time or on any subset of the characters used in three_stage_prep().
    # Input image stats are all in ink units. See comments at top of function about why it's OK
    # to apply the trivial conversion to PNG grayscale. The output of ink_to_png_8bit_grayscale()
    # is defined so that black is 0.

    threshold1,threshold2,threshold3,sigma,a,laxness,smear,max_hits = self.pars
    stats = page.stats
  
    bw = {}
    red = {}
    sdp = {}
    pat_by_name = {}
    chars.chars.each { |c|
      n = char_to_short_name(c)
      p = set.pat(c)
      pat_by_name[n] = p
      bw[n] = image_to_ink_array(p.bw)
      red[n] = image_to_ink_array(p.red)
      pat_stats = ink_stats_pat(bw[n],red[n]) # calculates mean and sd
      sdp[n] = pat_stats['sd']
    }

    make_scatterplot = false

    hits2 = []
    bg = stats['background']
    if make_scatterplot then scatt=[] end
    self.hits.each { |x|
      co1,i,j,misc = x
      short_name = misc['label']
      norm = sdp[short_name]*stats['sd_in_text']
      co2 = correl(page.ink,bw[short_name],red[short_name],bg,i,j,norm)
      debug=nil
      co3,garbage = squirrel(page.ink,bw[short_name],red[short_name],i,j,stats,smear:smear,debug:debug)
      if make_scatterplot then scatt.push([co1,co3]) end
      #if co2>0.0 then print "i,j=#{i} #{j} raw=#{co1}, co2=#{co2}, co3=#{co3}\n" end
      if co2<threshold2 then next end
      if co3<threshold3 then next end
      hits2.push(x)
    }
    print "filtered #{self.hits.length} to #{hits2.length}\n"

    unless self.monitor_file.nil? then png_report(self.monitor_file,page.image,hits2,chars,set,verbosity:2) end
    if make_scatterplot then print ascii_scatterplot(hits2,save_to_file:'scatt.txt') end

    return hits2
  end
end

def swatches(hits,text,pat,stats,char,cluster_threshold)
  verbosity=2
  # Generates images for the best matches in the text for a particular pattern.
  # Analyzes them into clusters. Returns a composite image (ChunkyPNG object) for the best-matching cluster.
  nhits = hits.length
  wt,ht = text.width,text.height
  wp,hp = pat.width,pat.height
  if nhits>10 then nhits=10 end
  images = []
  0.upto(nhits-1) { |k|
    c,i,j,misc = hits[k]
    if i+wp>wt or j+hp>ht then print "Not doing swatch #{k}, hangs past edge of page.\n"; next end
    sw = text.crop(i,j,wp,hp)
    fatten = (stats['x_height']*0.09).round # rough guess as to how much to fatten up the red mask so that we get everything
    mask_to_background(sw,pat.red,stats['background'],fatten)
    # This erases nearby characters, but can also have the effect of erasing part of a mismatched letter. For example,
    # an ε in the seed font can match α in the text. Masking gets rid of the two "twigs" on the right side of the alpha
    # and makes it look like an omicron.
    enhance_contrast(sw,stats['background'],stats['threshold'],stats['dark'])
    images.push(sw)
    if verbosity>=3 then sw.save("swatch#{k}.png") end
  }
  c = correlate_swatches(images,char)
  clusters = find_clusters(c,cluster_threshold)
  print "clusters:\n"
  clusters.each { |cl|
    print "  #{cl}\n"
  }
  cl_averages = []
  clusters.each { |cl|
    member_images = cl.map {|i| images[i]}
    av = average_images(member_images)
    enhance_contrast(av,0.0,0.5,1.0,do_foreground:false,do_background:true)
    remove_flyspecks(av,0.25,1)
    cl_averages.push(av)
  }
  i = 0
  cl_averages.each { |cl_avg|
    if verbosity>=3 then cl_avg.save("cl#{i}.png") end
    i += 1
  }
  return cl_averages
end

def correlate_swatches(images,char)
  flat = []
  images.each  { |image|
    flat.push(image_to_list_of_floats(image))
  }
  n = flat.length
  mean = []
  sd = []
  flat.each { |f|
    m,s = find_mean_sd(f)
    mean.push(m)
    sd.push(s)
  }
  c = generate_array(n,n,lambda { |i,j|
      u = mean_product_simple_list_of_floats(flat[i],flat[j])
      return (u-mean[i]*mean[j])/(sd[i]*sd[j])
  },symm:true)
  print "correlation matrix for character '#{char}' swatches 0-#{n-1}:\n"
  print array_to_string(c,"  ","%3d",fn:lambda {|x| (x*100).round}),"\n"
  return c
end

def match_prep_monitor_file_helper(if_monitor_file,page)
  if !if_monitor_file then return nil end
  monitor_file = temp_file_name_short(prefix:"mon")+".png"
  monitor_file = "mon.png"; print "---- using deterministic name mon.png for convenience, won't work with parallelism ---\n"
  monitor_image = page.image.clone.grayscale
  monitor_image.save(monitor_file)
  print "monitor file: #{monitor_file} (can be viewed live using okular)\n"
  # ...  https://unix.stackexchange.com/questions/167808/image-viewer-with-auto-reload-on-file-change
  return monitor_file
end

def three_stage_cleanup(page)
  self.files_to_delete.each { |f|
    FileUtils.rm_f(f)
  }
  match_clean_monitor_file_helper(!(self.monitor_file.nil?),self.monitor_file)
end

def match_clean_monitor_file_helper(if_monitor_file,monitor_file)
  if !if_monitor_file then return end
  print "monitor file #{monitor_file} not being deleted for convenience ---\n"
  #FileUtils.rm_f(monitor_file)
end
