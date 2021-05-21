def ink_stats_pat(bw,red)
  data = []
  wp,hp = ink_array_dimensions(bw)
  0.upto(wp-1) { |i|
    0.upto(hp-1) { |j|
      if red[i][j]>0.0 then next end
      data.push(bw[i][j])
    }
  }
  mean,sd = find_mean_sd(data)
  return {'mean'=>mean,'sd'=>sd}
end

def ink_stats_1(image)
  sample = random_sample(image,1000,nil,nil) # nothing bad happens if the image has less than 1000 pixels, we just get a smaller sample
  median = find_median(sample)
  min = sample.min
  max = sample.max
  mean,sd = find_mean_sd(sample)
  submedian,supermedian = find_sup_sub_median(sample,mean)
  # The submedian seems like an excellent estimate of the background.
  # The supermedian is systematically a lot lower than the darkest ink color.
  # For scanned text, the distribution doesn't really look bimodal, it looke more like what I get if I hold up my left hand and
  # make a sign-language "L." There's a huge peak that is the whitespace, then a fairly flat distribution of gray tones
  # going up to some cut-off. There is only a very slight hump where you'd expect the upper peak to have been. This
  # would certainly look very different on something like a monochrome computer font, or possibly at higher resolution.
  threshold,dark = dark_ink(sample,median,submedian,supermedian,max)
  return {'median'=>median,'min'=>min,'max'=>max,'mean'=>mean,'sd'=>sd,
        'submedian'=>submedian,'supermedian'=>supermedian,'threshold'=>threshold,'dark'=>dark}
end

def ink_stats_2(image,stats,scale)
  # Scale is an estimate of something like the x-height, 
  # used so we can get some kind of guess as to how far we have to be from ink to be in total whitespace
  threshold = stats['threshold']
  sample_in_text = random_sample(image,1000,threshold,scale)
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
  return [x,result2]
end

