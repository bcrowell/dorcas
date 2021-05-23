# coding: utf-8
def match(text,pat,stats,threshold)
  # text is a ChunkyPNG object
  # pat is a Pat
  # stats is is a hash describing the text, the most important member being line_spacing
  # threshold is the lowest correlation that's of interest

  text_line_spacing = stats['line_spacing']  
  scale = text_line_spacing/pat.line_spacing

  wt,ht = text.width,text.height
  wp,hp = pat.bw.width,pat.bw.height
  wbox = pat.bbox[1]-pat.bbox[0]+1 # width of black
  lbox = pat.bbox[0] # left side of black
  rbox = pat.bbox[1] # right side of black

  text_ink = image_to_ink_array(text)
  bw_ink = image_to_ink_array(pat.bw)
  red_ink = image_to_ink_array(pat.red)
  pat_stats = ink_stats_pat(bw_ink,red_ink) # calculates mean and sd
  print "pat_stats: #{stats_to_string(pat_stats)}\n"

  sdt = stats['sd_in_text']
  sdp = pat_stats['sd']
  norm = sdt*sdp # normalization factor for correlations
  # i and j are horizontal and vertical offsets of pattern relative to text; non-black part of pat can stick out beyond edges
  j_lo = pat.bbox[2]-pat.line_spacing
  j_hi = ht-1+pat.bbox[3]
  i_lo = -lbox
  i_hi = wt-1-rbox
  results = []
  i_lo.upto(i_hi) { |i|
    col = []
    j_lo.upto(j_hi) { |j|
      col.push(nil)
    }
    results.push(col)
  }
  highest_corr = 0.0
  results = correl_many(text_ink,bw_ink,red_ink,stats['background'],i_lo,i_hi,j_lo,j_hi,text_line_spacing.to_i,norm)

  hits = []
  xr = ((pat.bbox[1]-pat.bbox[0])*0.8).round
  yr = ((pat.bbox[3]-pat.bbox[2])*0.8).round
  (j_lo+yr).upto(j_hi-yr) { |j|
    (i_lo+xr).upto(i_hi-xr) { |i|
      c = results[j-j_lo][i-i_lo]
      if c>threshold then
        local_max = true
        (-xr).upto(xr) { |di|
          (-yr).upto(yr) { |dj|
            if results[j+dj-j_lo][i+di-i_lo]>c then local_max=false end
          }
        }
        if local_max then
          ci = (i+wp/2).round
          cj = (j+hp/2).round
          hits.push([c,i,j])
        end
      end
    }
  }
  hits.sort! {|a,b| b[0] <=> a[0]} # sort in descending order by score
  print "hits:\n"
  count = 0
  hits.each { |hit|
    print sprintf("  %2d corr=%4.2f x=%4d y=%4d\n",count,hit[0],hit[1],hit[2])
    count += 1
  }
  return hits
end

def swatches(hits,text,pat,stats)
  # Generates images for the best matches in the text for a particular pattern.
  # Analyzes them into clusters. Returns a composite image for the best-matching cluster.
  nhits = hits.length
  wt,ht = text.width,text.height
  wp,hp = pat.width,pat.height
  if nhits>10 then nhits=10 end
  images = []
  0.upto(nhits-1) { |k|
    c,i,j = hits[k]
    if i+wp>wt or j+hp>ht then print "Not doing swatch #{k}, hangs past edge of page.\n" end
    sw = text.crop(i,j,wp,hp)
    fatten = (stats['x_height']*0.09).round # rough guess as to how much to fatten up the red mask so that we get everything
    mask_to_background(sw,pat.red,stats['background'],fatten)
    # This erases nearby characters, but can also have the effect of erasing part of a mismatched letter. For example,
    # an ε in the seed font can match α in the text. Masking gets rid of the two "twigs" on the right side of the alpha
    # and makes it look like an omicron.
    enhance_contrast(sw,stats['background'],stats['threshold'],stats['dark'])
    images.push(sw)
    sw.save("swatch#{k}.png")
  }
  c = correlate_swatches(images)
  clusters = find_clusters(c,0.85)
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
    cl_avg.save("cl#{i}.png")
    i += 1
  }
  return cl_averages[0]
end

def correlate_swatches(images)
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
  print "correlation matrix for swatches 0-#{n-1}:\n"
  print array_to_string(c,"  ","%3d",fn:lambda {|x| (x*100).round})
  return c
end
