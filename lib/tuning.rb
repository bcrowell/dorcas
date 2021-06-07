def three_stage_guess_pars(page,xheight)
  est_max_chars = 0.3*page.width*page.height/(xheight*xheight)
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

  return [threshold1,threshold2,threshold3,sigma,a,smear,max_hits]
end
