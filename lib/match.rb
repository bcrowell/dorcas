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
          print " local max: center,correl=#{ci},#{cj},#{c}\n"
          hits.push([i,j])
        end
      end
    }
  }
  return hits
end

