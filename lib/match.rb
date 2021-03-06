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
      characters = scripts.map { |s| s.alphabet_with_large_punctuation(c:"both") }.inject('') {|s1,s2| s1+s2} # both upper and lower case in every script
    end
    @characters = characters
    @meta_threshold = meta_threshold
    # Force_location stuff. In the following, force_locs, if present, has already been converted into the form {'Ψ'=>[123,456]}.
    # We can't convert this into boxes yet because we don't have page dimensions or font metrics.
    @locs = {} # a hash whose keys are names of characters and whose values are points [x,y] or empty arrays []
    characters.chars.each { |c| @locs[char_to_short_name(c)] = []} # fill in defaults
    if !(force_loc.nil?) then force_loc.each { |c,p| @locs[char_to_short_name(c)] = p } end # overwrite defaults with actual values
  end

  attr_reader :scripts,:characters
  attr_accessor :meta_threshold,:hits
  attr_accessor :pars,:monitor_file,:files_to_delete,:batch_code,:locs,:boxes # private methods

  def n_chars
    return self.characters.length
  end

  def execute(page,set,page_code,batch_code:'',if_monitor_file:true,verbosity:1)
    # Three-stage matching consisting of freak, simple correlation, and squirrel.
    # Page must have .stats containing an 'x_height' key, which is used to estimate parameters for peak detection kernel and maximum number of hits.
    # Stats should also contain keys 'background', 'dark', and 'threshold'.

    self.batch_code = batch_code

    self.three_stage_prep(page,set,page_code,if_monitor_file:if_monitor_file)
    console "  Done with fft for #{self.characters}.\n" if verbosity>=2
    count1,hits2 = self.three_stage_pass_2(page,set)
    hits3 = self.three_stage_pass_3(page,set,hits2)
    self.three_stage_cleanup(page)
    self.hits = hits3

    return hits3
  end

  def three_stage_prep(page,set,page_code,if_monitor_file:true,verbosity:1)
    # This runs the first of the three stages, using fft convolution. This is the part that parallelizes well to multiple cores, and for
    # performance should be called with many characters at once in self.characters.
    # It stores all the hits from the first stage in self.hits, and these can
    # then be run through the later stages using three_stage_complete(), which can be called one character at a time if desired.
    if verbosity>=1 then console "Scanning the page for characters, pass 1 of 3.\n" end
    die("stats= #{page.stats.keys}, does not contain required stats") unless array_subset?(['x_height','background','dark','threshold'],page.stats.keys)
    die("set is nil") if set.nil?
    die("batch_code is nil") if self.batch_code.nil?
    @boxes = {}
    @locs.each { |char_name,p|
      if p.length==0 then 
        b=page.box
      else
        x,y = p
        l = page.stats['x_height'] # just get some idea of the scale; this could be refined by using more specific font metrics, line spacing
        dx1,dx2,dy1,dy2 = -2*l,l,-2*l,l # asymmetric ranges, because the pattern's defining point is the upper left corner
        b=Box.new(x+dx1,x+dx2,y+dy1,y+dy2)
      end
      @boxes[char_name] = b.intersection(page.box)
    }
    self.monitor_file=match_prep_monitor_file_helper(if_monitor_file,page)
    xheight = page.stats['x_height']
    self.pars = three_stage_guess_pars(page,xheight,self.n_chars,meta_threshold:self.meta_threshold)
    threshold1,threshold2,threshold3,sigma,a,laxness,smear,max_hits = self.pars
    outfile = temp_file_name()
    # ...Gets appended to; each hit is marked by batch code and character's label.
    #    I used to make this peaks.txt, so it was easy to watch it with tail -f, etc., but that created problems when I started accumulating
    #    multiple pages of results in the same file.
    if verbosity>=2 then console "Writing fft results to #{outfile}\n" end
    self.hits,self.files_to_delete = freak(page,self.characters,set,outfile,page.stats,threshold1,@boxes,
                    sigma,a,laxness,max_hits,batch_code:self.batch_code)
    self.files_to_delete.push(outfile)
  end

  def three_stage_pass_2(page,set,chars:self.characters,verbosity:2)
    # This can be called on one character at a time or on any subset of the characters used in three_stage_prep().
    # Input image stats are all in ink units. See comments at top of function about why it's OK
    # to apply the trivial conversion to PNG grayscale. The output of ink_to_png_8bit_grayscale()
    # is defined so that black is 0.
    # Returns [count1,hits2], where 
    #   count1 is a hash whose keys are characters and whose values are the number of hits from pass 1
    #   hits2 is a hash whose keys are characters and whose values are lists of hits in the format [score,x,y]
    if verbosity>=1 then console "Scanning the page for characters, pass 2 of 3.\n" end

    threshold1,threshold2,threshold3,sigma,a,laxness,smear,max_hits = self.pars
    stats = page.stats
  
    want_these_chars = {}
    sdp = {}
    pat_by_name = {}
    bw = {}
    red = {}
    count1 = {}
    hits2 = {}
    chars.chars.each { |c|
      n = char_to_short_name(c)
      count1[c] = 0
      hits2[c] = []
      p = set.pat(c)
      want_these_chars[n] = true
      bw[n] = image_to_ink_array(p.bw)
      red[n] = image_to_ink_array(p.pink)
      pat_by_name[n] = p
      sdp[n] = p.stats['sd']
    }

    bg = stats['background']
    self.hits.each { |x|
      co1,i,j,misc = x
      short_name = misc['label']
      next unless want_these_chars.has_key?(short_name)
      c = short_name_to_char(short_name)
      count1[c] += 1
      norm = sdp[short_name]*stats['sd_in_text']
      co2 = correl(page.ink,bw[short_name],red[short_name],bg,i,j,norm)
      if co2<threshold2 then next end
      hits2[c].push([co2,i,j])
    }
    return [count1,hits2]
  end

  def three_stage_pass_3(page,set,hits2,chars:self.characters,verbosity:1)
    # hits2 is a hash whose keys are characters and whose values are lists of hits in the format [score,x,y], where score is from pass 2
    # hits3 is in the same format, but filtered again, and with score from pass 3 possibly perturbed x and y
    threshold1,threshold2,threshold3,sigma,a,laxness,smear,max_hits = self.pars

    if threshold3<0.8 then zz=0.8-threshold3; k=[0.5,3-7*zz].max else k=3.0 end

    if verbosity>=1 then console "Scanning the page for characters, pass 3 of 3.\n" end

    n = guess_n_cores()
    μοῖραι = portion_out_characters(chars,n)
    if verbosity>=3 then console "    μοῖραι=#{μοῖραι}\n" end
    files_to_delete = []
    page_file = temp_file_name()
    files_to_delete.push(page_file)
    File.open(page_file,"wb") { |file| Marshal.dump(page,file) } # slow operation, takes about 2 seconds for a full page
    pars = {'threshold'=>threshold3,'max_scooch'=>1,'smear'=>smear,'k'=>k}

    outfiles = []
    pids = []
    μοῖραι.each { |these_chars|
      next if these_chars==''
      hh = these_chars.chars.each.map { |c| hits2[c] }   # hits in format needed for spawned process
      pp = these_chars.chars.each.map { |c| set.pat(c) } # pats in format needed for spawned process
      infiles = []
      [pp,hh,pars].each { |x|
        file = temp_file_name()
        infiles.push(file)
        files_to_delete.push(file)
        File.open(file,"wb") { |file| Marshal.dump(x,file) }
      }
      outfile = temp_file_name()
      files_to_delete.push(outfile)
      outfiles.push(outfile)
      myself = find_exe(nil,"dorcas")
      if verbosity>=4 then console "  spawning a squirrel\n" end
      pid = Process.spawn(myself,"squirrel",page_file,infiles[0],infiles[1],infiles[2],outfile)
      lower_priority(pid)
      pids.push(pid)
    }
    if verbosity>=4 then console "  waiting for squirrels\n" end
    pids.each { |pid| Process.wait(pid)  }
    if verbosity>=4 then console "  done waiting for squirrels\n" end

    hits3 = {}
    outfiles.each { |outfile|
      File.open(outfile,"rb") { |file| hits3 = hits3.merge(Marshal.load(file)) }
    }
    delete_files(files_to_delete)

    unless self.monitor_file.nil? then png_report(self.monitor_file,page.image,hits3,chars,set,verbosity:2) end

    return hits3
  end

  def three_stage_cleanup(page)
    self.files_to_delete.each { |f|
      FileUtils.rm_f(f)
    }
    match_clean_monitor_file_helper(!(self.monitor_file.nil?),self.monitor_file)
 end

  def count_candidates(c)
    count = 0
    n = char_to_short_name(c)
    self.hits.each { |x|
      co1,i,j,misc = x
      short_name = misc['label']
      if short_name==n then count +=1 end
    }
    return count
  end

end

def swatches(hits,text,pat,stats,char,cluster_threshold)
  verbosity=2
  # Generates images for the best matches in the text for a particular pattern.
  # Analyzes them into clusters. Returns a list of chunkypng images for the swatches.
  nhits = hits.length
  wt,ht = text.width,text.height
  wp,hp = pat.width,pat.height
  images = []
  #print "in swatches, nhits=#{nhits}\n"
  0.upto(nhits-1) { |k|
    score,i,j = hits[k]
    if i+wp>wt or j+hp>ht then console "Not doing swatch #{k}, hangs past edge of page.\n"; next end
    sw = text.crop(i,j,wp,hp)
    remove_impinging_flyspecks(sw,pat,stats)
    enhance_contrast(sw,stats['background'],stats['threshold'],stats['dark'])
    images.push(sw)
    if verbosity>=3 then sw.save("swatch#{k}.png") end
  }
  return images
end

def find_clusters_of_swatches(images,char,cluster_threshold)
  # Images is a list of cunkypng images. Char is just for informational output.
  c = correlate_swatches(images,char)
  clusters = find_clusters(c,cluster_threshold)
  console "clusters:\n"
  count = 0
  clusters.each { |cl|
    count += 1 # prefer_cluster uses 1-based numbering
    console "  cluster #{count}: #{cl}\n"
  }
  return clusters
end

def make_composite_from_swatches(pat,images,clusters,verbosity:1)
  # Returns a set of images and a list of lists of integers that specifies clusters of these images.
  # Returns a list in which each element is a composite of one cluster.
  # Pat is optional. If not nil, it helps us to do more removal of glitches from pink areas.
  cl_averages = []
  clusters.each { |cl|
    member_images = cl.map {|i| images[i]}
    av = average_images(member_images)
    enhance_contrast(av,0.0,0.5,1.0,do_foreground:false,do_background:true)
    remove_flyspecks(av,0.25,1)
    remove_flyspecks(av,0.5,1,mask:pat.pink)
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
  # Images is a list of cunkypng images. Char is just for informational output.
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
  console "correlation matrix for character '#{char}' swatches 0-#{n-1}:\n"
  console array_to_string(c,"  ","%3d",fn:lambda {|x| (x*100).round}),"\n"
  return c
end

def match_prep_monitor_file_helper(if_monitor_file,page)
  if !if_monitor_file then return nil end
  monitor_file = temp_file_name_short(prefix:"mon")+".png"
  monitor_file = "mon.png";
  monitor_image = clown(page.image).grayscale
  monitor_image.save(monitor_file)
  #console "  monitor file: #{monitor_file} (can be viewed live using okular)\n"
  # ...  https://unix.stackexchange.com/questions/167808/image-viewer-with-auto-reload-on-file-change
  return monitor_file
end

def match_clean_monitor_file_helper(if_monitor_file,monitor_file)
  if !if_monitor_file then return end
  #console "  monitor file #{monitor_file} not being deleted for convenience ---\n"
  #FileUtils.rm_f(monitor_file)
end

def remove_impinging_flyspecks(sw,pat,stats)
  # Changes sw in place.
  # Try to get rid of parts of other nearby characters that are impinging on this swatch and creating dots and glitches.
  # This erases nearby characters, but can also have other effects. (1) Can erase part of a mismatched letter. For example,
  # an ε in the seed font can match α in the text. Masking gets rid of the two "twigs" on the right side of the alpha
  # and makes it look like an omicron. (2) Can erase part of a correctly matched letter. This happened with ϊ from p. 10 of Giles.
  # Doing box_to_leave_alone is meant to prevent case 2 from happening. The bbox may not be perfectly correct (is probably left
  # over from seed font), but is probably a reasonable guide. It's also possible for other characters to come into the bbox, due to kerning.
  # A better way to do this would be to get enough matches so that impinging flyspecks go away simply through averagine in the composite.
  scale = (stats['x_height']*0.09).round # rough measure of the scale of intercharacter spaces
  fatten = scale # rough guess as to how much to fatten up the red mask so that we get everything
  box_to_leave_alone = Box.from_a(pat.bbox).fatten(scale/2)
  mask_to_background(sw,pat.red,stats['background'],fatten,box_to_leave_alone)
end
