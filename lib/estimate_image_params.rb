def ink_stats_pat(bw,red)
  data = []
  wp,hp = ink_array_dimensions(bw)
  if !same_dimensions(bw,red) then die("bw and red have different dimensions") end
  0.upto(wp-1) { |i|
    0.upto(hp-1) { |j|
      if red[i][j]>0.0 then next end
      data.push(bw[i][j])
    }
  }
  mean,sd = find_mean_sd(data)
  return {'mean'=>mean,'sd'=>sd}
end

def ink_sample_size()
  # Used by ink_stats_1() and ink_stats_2(). Changing this to 10000 eats up 4 seconds of CPU time.
  return 1000
end

def ink_stats_1(image,ink_array)
  # Input is chunkypng, but outputs are in ink units.
  # I've added a redundant second argument ink_array for efficiency, should use that as much as possible.
  # The following two lines are extremely fast.
  max = array_max(ink_array)
  min = array_min(ink_array)
  sample = random_sample(ink_array,ink_sample_size(),nil,nil) # nothing bad happens if the image has less than this many pixels, we just get a smaller sample
  median = find_median(sample)
  mean,sd = find_mean_sd(sample)
  submedian,supermedian = find_sup_sub_median(sample,mean)
  # The submedian seems like an excellent estimate of the background.
  # The supermedian is systematically a lot lower than the darkest ink color.
  # For scanned text, the distribution doesn't really look bimodal, it looke more like what I get if I hold up my left hand and
  # make a sign-language "L." There's a huge peak that is the whitespace, then a fairly flat distribution of gray tones
  # going up to some cut-off. There is only a very slight hump where you'd expect the upper peak to have been. This
  # would certainly look very different on something like a monochrome computer font, or possibly at higher resolution.
  # Also need to consider the case where the image is almost all blank except for, say, one character.
  threshold,dark = dark_ink(sample,median,submedian,supermedian,max)
  background = submedian
  if dark<threshold+0.3 then dark=threshold+0.3 end # Happens when the page is almost completely empty but does contain some text.
  coverage = fraction_over_trigger_level(sample,threshold)
  w = 0.75
  threshold2 = w*background+(1.0-w)*dark # an independent estimate, w was derived from some faded text so as to give a reasonable threshold
  if threshold>threshold2 then threshold=threshold2 end # try to make sure it's not too high, which is really bad
  return {'background'=>background,'median'=>median,'min'=>min,'max'=>max,'mean'=>mean,'sd'=>sd,
        'submedian'=>submedian,'supermedian'=>supermedian,'threshold'=>threshold,'dark'=>dark,'coverage'=>coverage}
end

def ink_stats_2(image,ink_array,stats,scale)
  # Scale is an estimate of something like the x-height, 
  # used so we can get some kind of guess as to how far we have to be from ink to be in total whitespace
  threshold = stats['threshold']
  sample_in_text = random_sample(ink_array,ink_sample_size(),threshold,scale)
  mean_in_text,sd_in_text = find_mean_sd(sample_in_text)
  return stats.merge({'mean_in_text'=>mean_in_text,'sd_in_text'=>sd_in_text})
end

def dark_ink(sample,median,submedian,supermedian,max)
  # Returns [threshold,dark].
  # Threshold is meant to be a value such that anything over this value is definitely due to ink.
  # Dark is meant to be an estimate of a typical ink level for a fully inked solid region. This is meant to give something reasonable
  # both in the case where there is a prominent upper peak in the distribution and in the case where there isn't.
  w = 0.4
  trough = (1.0-w)*submedian+w*max # try to find a spot that is to the right of the huge whitespace peak
  x = 0.5*(trough+supermedian) # a spot that is to the left of any upper peak
  # The following is equivalent to finding the 75th percentile for the portion of the distribution above x.
  # On a sample of scanned text, this came out to be what I judged to be the center of the (not very prominent) upper peak.
  # On something closer to monochrome data, this will come out to be on the right-hand shoulder of the top peak, i.e., it will be slightly biased.
  # On perfect monochrome data, it should be equal to the upper peak value.
  garbage,result1 = find_sup_sub_median(sample,x)
  garbage,result2 = find_sup_sub_median(sample,result1)
  return [trough,result2]
end

