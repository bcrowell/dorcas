# coding: utf-8
def match(text,pat,stats,threshold,force_loc,max_hits)
  # text is a ChunkyPNG object
  # pat is a Pat
  # stats is is a hash describing the text, the most important member being line_spacing
  # threshold is the lowest correlation that's of interest

  verbosity=2

  text_line_spacing = stats['line_spacing']  

  wt,ht = text.width,text.height
  wp,hp = pat.bw.width,pat.bw.height
  wbox = pat.bbox[1]-pat.bbox[0]+1 # width of black
  lbox = pat.bbox[0] # left side of black
  rbox = pat.bbox[1] # right side of black

  text_ink = image_to_ink_array(text)
  bw_ink = image_to_ink_array(pat.bw)
  red_ink = image_to_ink_array(pat.red)
  pat_stats = ink_stats_pat(bw_ink,red_ink) # calculates mean and sd
  if verbosity>=3 then print "  pat_stats: #{stats_to_string(pat_stats)}\n" end

  sdt = stats['sd_in_text']
  sdp = pat_stats['sd']
  norm = sdt*sdp # normalization factor for correlations
  # i and j are horizontal and vertical offsets of pattern relative to text; non-black part of pat can stick out beyond edges
  # Nominal region of text to consider:
  if force_loc.nil? then
    i0,j0,nom_di,nom_dj = [0,0,wt-1,ht-1]
  else
    if verbosity>=2 then print "  Forcing location to be near #{force_loc}.\n" end
    # Don't make fuzz too small. This radius later has a certain radius subtracted off of it when we look for local maxima (see code with xr,yr below).
    # If that makes the effective region extremely small or nonexistent, we generate a warning below.
    fuzz = 1.0*pat.line_spacing
    fuzz_x = (3.0*fuzz).round
    fuzz_y = (1.0*fuzz).round
    i0,j0,nom_di,nom_dj = [force_loc[0]-fuzz_x,force_loc[1]-fuzz_y,2*fuzz_x,2*fuzz_y]
    if i0<0 then i0=0 end
    if i0+nom_di>wt-1 then nom_di=wt-1-i0 end
    if j0<0 then j0=0 end
    if j0+nom_dj>ht-1 then nom_dj=ht-1-j0 end
    if verbosity>=3 then print "  i0,j0,nom_di,nom_dj=#{[i0,j0,nom_di,nom_dj]}\n" end
  end
  j_lo = j0+pat.bbox[2]-pat.line_spacing
  j_hi = j0+nom_dj+pat.bbox[3]
  i_lo = i0-lbox
  i_hi = i0+nom_di-rbox
  results = correl_many(text_ink,bw_ink,red_ink,stats['background'],i_lo,i_hi,j_lo,j_hi,text_line_spacing.to_i,norm)

  hits = filter_hits(results,Box.from_a(pat.bbox),Box.new(i_lo,i_hi,j_lo,j_hi),threshold,max_hits,verbosity:verbosity)

  print "hits:\n"
  count = 0
  hits.each { |hit|
    print sprintf("  %2d corr=%4.2f x=%4d y=%4d\n",count,hit[0],hit[1],hit[2])
    count += 1
    if count>10 then print "  ...plus more hits for a total of #{hits.length}\n"; break end
  }
  return hits
end

def filter_hits(results,pat_bbox,region,threshold,max_hits,verbosity:1)
  # pat_bbox and region should be Box objects.
  # Returns an array whose elements are of the form [c,i,j], where c is the correlation score,
  # and i and j are the location. This will be sorted in decreasing order by score.
  # We look for correlation scores that are local maxima and are above threshold.
  # The following is pretty slow when there is a large number of hits, and we don't know
  # in advance how many hits there will be, hence the need for the max_hits parameter. 
  # When looking for patterns to match a seed font, max_hits can be set pretty low,
  # and a large number of hits is basically a symptom that the threshold has been set too low.
  # Performance will be more of a problem when actually OCRing a full page of text.
  # One way to speed things up would be to avoid looking at candidates that aren't on a baseline of text.
  bbox = pat_bbox.to_a
  i_lo,i_hi,j_lo,j_hi = region.to_a
  hits = []
  # Set a radius within which we look for the greatest value.
  r_frac = 0.1
  # ... Making this >=1 would prevent matching a double letter like the mm in "common." Even slightly smaller values could cause the
  #     software to refuse to find a character in a certain spot because it was convinced that another character was nearby.
  #     Large values also make the algorithm extremely slow.
  #     Making the value too small will tend to give more bogus and overlapping hits.
  #     Looking at heat maps of correlations, the real hits are spikes that are pretty tall and have a radius of about 0.1 in these units.
  #     On a sample of text, it seemed to make little difference in the results whether this was set to 0.1 or 0.8, provided that the
  #     threshold was set to roughly the right value to make the best distinction between good and false matches. When setting the
  #     threshold lower, the value of r_frac will matter a lot more, and if the intention is to get lots of matches and winnow them
  #     later, then a small r_frac may still be the right choice.
  xr = ((bbox[1]-bbox[0])*r_frac).round
  yr = ((bbox[3]-bbox[2])*r_frac).round
  j0,j1,i0,i1 = [j_lo+yr,j_hi-yr,i_lo+xr,i_hi-xr]
  if j1<j0 or i1<i0 then warn("window in match() contains no pixels, no results returned"); return end
  if j1-j0<yr or i1-i0<xr then warn("window in match() is only #{i1-i0+1}x#{j1-j0+1}, probably no results will be returned") end
  if verbosity>=4 then print "  results near #{[j0,j1,i0,i1]}:\n",array_to_string(extract_subarray(results,i0,i1,j0,j1),2,"%5.2f"),"\n" end
  j0.upto(j1) { |j|
    i0.upto(i1) { |i|
      c = results[j-j_lo][i-i_lo]
      if c>threshold then
        local_max = true
        (-xr).upto(xr) { |di|
          (-yr).upto(yr) { |dj|
            if results[j+dj-j_lo][i+di-i_lo]>c then local_max=false; break end
          }
          if !local_max then break end
        }
        if local_max then
          hits.push([c,i,j])
          if hits.length>=max_hits then break end
        end
      end
    }
    if hits.length>=max_hits then break end
  }
  hits.sort! {|a,b| b[0] <=> a[0]} # sort in descending order by score
  return hits
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
