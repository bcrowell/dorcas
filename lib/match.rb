# coding: utf-8

class Match
  # Describes a plan of attack for OCRing text. Includes thresholds, a list of characters to be matched, and
  # options such as forcing a character to be matched near a certain location on the page.
  # Forcing location is not yet implemented. When implementing it, use squirrel only, not freak. See old code
  # in git commit cda9ba6ff452a0b508 , file match.rb, function old_match().
  def initialize(scripts:nil,characters:nil)
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
  end

  attr_reader :scripts,:characters

  def execute(page,set,verbosity:2,batch_code:'')
    # caller can get set from job.set. Page must have .stats containing an 'x_height' key, which
    # is used to estimate parameters for peak detection kernel and maximum number of hits.
    # Stats should also contain keys 'background', 'dark', and 'threshold'.

    unless ['x_height','background','dark','threshold'].to_set.subset?(page.stats.keys.to_set) then
      die("stats has keys #{stats.keys}, does not contain the required ones")
    end

    stats = page.stats
    text = page.image
    text_ink = page.ink

    if true then
      monitor_file = temp_file_name_short(prefix:"mon")+".png"
      monitor_file = "mon.png"; print "---- using deterministic name mon.png for convenience, won't work with parallelism ---\n"
      monitor_image = text.clone.grayscale
      monitor_image.save(monitor_file)
      print "monitor file: #{monitor_file} (can be viewed live using okular)\n"
      # ...  https://unix.stackexchange.com/questions/167808/image-viewer-with-auto-reload-on-file-change
    end

    hits = three_stage(page,self.characters,set,stats,batch_code,monitor_file:monitor_file)

    if true then
      print "monitor file #{monitor_file} not being deleted for convenience ---\n"
      #FileUtils.rm_f(monitor_file)
    end

  end
end

def three_stage(page,chars,set,stats,batch_code,monitor_file:nil)
  xheight = stats['x_height']

  pars = three_stage_guess_pars(page,xheight)
  threshold1,threshold2,threshold3,sigma,a,smear,max_hits = pars

  # Input image stats are all in ink units. See comments at top of function about why it's OK
  # to apply the trivial conversion to PNG grayscale. The output of ink_to_png_8bit_grayscale()
  # is defined so that black is 0.
  stats = page.stats

  # Three-stage matching consisting of freak, simple correlation, and squirrel.
  outfile = 'peaks.txt' # gets appended to; each hit is marked by batch code and character's label
  hits,files_to_delete = freak(page,chars,set,outfile,page.stats,threshold1,sigma,a,max_hits,batch_code:batch_code)

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
  hits.each { |x|
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
  print "filtered #{hits.length} to #{hits2.length}\n"
  hits = hits2

  unless monitor_file.nil? then png_report(monitor_file,page.image,hits,chars,set,verbosity:2) end
  if make_scatterplot then print ascii_scatterplot(hits,save_to_file:'scatt.txt') end

  files_to_delete.each { |f|
    FileUtils.rm_f(f)
  }

  return hits2
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
    c,i,j = hits[k]
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
