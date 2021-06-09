def three_stage_guess_pars(page,xheight,meta_threshold:0.5)
  # Returns all the necessary parameters for a three-stage match consisting of freak, simple correlation, and squirrel.
  est_max_chars = 0.3*page.width*page.height/(xheight*xheight)
  # ... The 0.3 was estimated from some sample text.
  est_max_freq = 0.13 # frequency of 'e' in English text, https://en.wikipedia.org/wiki/Letter_frequency
  est_max_one_char = est_max_freq*est_max_chars # estimated maximum number of occurrences of any character
  max_hits = (est_max_one_char*2).round # double the plausible number of occurrences
  #print "est_max_chars=#{est_max_chars}, est_max_freq=#{est_max_freq}, est_max_one_char=#{est_max_one_char}, max_hits=#{max_hits}\n"

  # I used testing to try to figure out how much it was reasonable to change each threshold. The results are incorporated
  # into logic below that takes the input meta_threshold and translates it into an actual set of thresholds.
  # The values for meta_threshold are meant to range from about 0 to 1, with 0.5 being a reasonable default.
  # Setting threshold1 very low incurs a big performance hit in peak detection and ends up bringing back only a few more
  # mathches  that would make it through later stages.
  # Setting threshold1:
  #   Comparing values of 0.0 and 0.2, the latter cut about half the matches while getting rid of only 1 of 51 hits later judged good by squirrel.
  #   At 0.2, we get about 18% false positives.
  # Setting threshold2:
  #   When other thresholds are set to reasonable values (t1=0.2, t3=0.0), setting t2 to any value less <=0.5 doesn't
  #   get rid of any matches. Setting it to 0.7 gives about 1/3 false negatives. Setting it fairly high gives me more
  #   room to make the final matching algorithm more cpu-intensive.
  # Setting threshold3:
  #   If you leave the earlier stages wide open (threshold1=-1, max_hits very high), then setting
  #   threshold3=-0.2 gives many obviously bad matches, 0 gives only a few false positives. If early stages are
  #   set much tighter, then threshold3 can be set as low as -0.5 with very few false positives.
  threshold1,threshold2,threshold3,laxness = [0.2,0.4,0.0,0.0]
  tighten = meta_threshold-0.5
  if tighten<0 then
    a1,a2,a3,al = [0.8,1.8,1.4,-2.0]
    x = 10**(-2*tighten)
    if x>30 then x=30 end
  else
    a1,a2,a3,al = [0.8,0.6,1.0,0.0]
    x = 1
  end
  threshold1,threshold2,threshold3,laxness = [threshold1+a1*tighten,threshold2+a2*tighten,threshold3+a3*tighten,laxness+al*tighten]
  max_hits = (max_hits*x).round
  if laxness<0.4 then laxness=0.4 end # otherwise kernel screws up on letters like "l," see comments at top of py/gaussian_cross.py

  smear = 2 # used in Pat.fix_red()

  # parameters for gaussian cross peak detection:
  sigma = xheight/10.0 # gives 3 for Giles, which seemed to work pretty well; varying sigma mainly just renormalizes scores
  a = (xheight/3.0).round # gives 10 for Giles; reducing it by a factor of 2 breaks peak detection; doubling it has little effect

  #print "threshold1,threshold2,threshold3,sigma,a,laxness,smear,max_hits=#{[threshold1,threshold2,threshold3,sigma,a,laxness,smear,max_hits]}\n"

  return [threshold1,threshold2,threshold3,sigma,a,laxness,smear,max_hits]
end
