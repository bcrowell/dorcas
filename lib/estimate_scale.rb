def estimate_scale(image,peak_to_bg,guess_dpi:300,guess_font_size:12,spacing_multiple:1.0,window:'hann',verbosity:1)
  # It helps if guess_dpi is right to within a factor of 2. Archive.org seems to use 500 dpi.
  # Use spacing_multiple=2 if it's double-spaced.
  # verbosity:
  #   1 -> reminds you, e.g., that it's only using left half of page
  #   2 -> a couple of brief lines of summary
  #   3 -> lots of step-by-step diagnostics, and writing of graphs
  proj = project_onto_y(image,0,image.width/2-1)
  if verbosity>=1 then print "Analyzing line spacing based on the left half of the page.\n" end
  # ... Doing only the left half of the image serves two purposes. If the image is rotated a little, then this mitigates the problem.
  #     Also, if there are two columns of text, then this will pick up only one. This could of course be the wrong choice in
  #     some cases, e.g., if there's a picture on the left side of the page.

  # Make an fft-friendly version of the projection:
  n = proj.length
  avg,sd = find_mean_sd(proj)
  pow2 = (Math::log(n)/Math::log(2.0)).to_i
  if 2**pow2<n then pow2=pow2+1 end
  nn = 2**pow2
  proj_windowed = windowing_and_padding(proj,window,nn,avg)

  line_spacing = estimate_line_spacing(proj,proj_windowed,n,nn,guess_dpi,guess_font_size,spacing_multiple,window,verbosity)

  font_height = estimate_font_height(proj,n,nn,line_spacing,avg,peak_to_bg,spacing_multiple,verbosity)

  return [line_spacing,font_height]
end

def estimate_font_height(proj,n,nn,line_spacing,avg,peak_to_bg,spacing_multiple,verbosity)
  # Try to estimate x-height. (Estimating capital height or hp height seems much harder.)

  # Need p_blur to be such that the peaks we pick off are really the center of the x-height.
  # Picked p_shoulder to give roughly the right x_height for this example.
  p_blur = 2.0 # for use in picking off phase of lines; frequencies above 2.5 times the fundamental get filtered out
  p_shoulder = 0.42 # pick off shoulders of projection at this level

  # Make a blurred copy of the projection so that we can get a good estimate of where the center of each line is.
  proj_windowed = windowing_and_padding(proj,'none',nn,avg) # make a projection without the Hann window
  fourier = fft(proj_windowed)
  # Low-pass filter:
  min_period = line_spacing/p_blur
  max_freq = (nn/min_period).round
  max_freq.upto(nn-1) { |i|
    fourier[i] = 0.0
  }
  # Reverse fourier:
  blurred = fft(fourier,direction:-1).map {|y| y.abs}
  nb = nn/2
  blurred = blurred[0..nb-1]
  if verbosity>=3 then make_graph("blurred.pdf",nil,blurred,"row","projection of left half") end

  top,bottom = greatest(blurred)[1],least(blurred)[1]
  mid = 0.5*(top+bottom)
  # Look for local maxima that are above mid.
  half_period = (line_spacing/2.0).round
  middies = []
  1.upto(nb-2) { |i|
    if not (blurred[i]>blurred[i-1] and blurred[i]>blurred[i+1]) then next end
    ok = true
    (i-half_period).upto(i+half_period) { |ii|
      if ii<0 or ii>nb-1 then next end
      if blurred[ii]>blurred[i] then ok=false; break end
    }
    if not ok then next end
    if verbosity>=4 then print "  found midpoint at #{i}\n" end
    middies.push(i)
  }

  # Make a copy of proj that's folded like an accordion pleat, so that we have a single average projection of a line of text.
  verbosity=3
  # The center goes at array index c.
  if verbosity>=4 then print "  half_period=#{half_period}\n" end
  c = (half_period).round
  na = 2*c
  a = []
  0.upto(na-1) { a.push(0.0) }
  middies.each { |mid|
    (-c).upto(c) { |offset|
      i = mid+offset
      if i<0 or i>n-1 then next end
      if offset+c<0 or offset+c>na-1 then next end
      a[offset+c] += proj[i] 
    }
  }
  # Try to subtract background:
  peak = greatest_in_range(a,c-half_period,c+half_period)[1]

  sane_x_height = 0.5*line_spacing/spacing_multiple # just a rough guess as a fallback
  x_height = sane_x_height

  if peak>0 then # not sure why sometimes I get peak==0, but avoid crashes when that happens
    bg1 = peak/peak_to_bg # estimate from global stats for the document
    bg2 = greatest_in_range(a,c-half_period,c+half_period,flip:-1)[1] # estimate from the accordion itself
    # bg2 seems to be higher, probably because crap gets in the tiny, narrow pure-white spaces between lines
    bg = greatest([bg1,bg2])[1]
    a = a.map{ |x| (x-bg)/(peak-bg)} # scale so that 1=max and 0=bg (approximately)
    if verbosity>=4 then print "half_period=#{half_period}, peak=#{peak}, bg=#{bg}\n" end
    if verbosity>=3 then make_graph("accordion.pdf",nil,a,"row","average projection") end
  
    # Try to guess x-height.
    f = p_shoulder # fraction of peak height at which we pick off the shoulder; set empirically from some sample text
    right_shoulder = nil
    c.upto(c+half_period) { |i|
      if i<0 or i>a.length-1 then next end
      if a[i]<f then right_shoulder=i; break end
    }
    left_shoulder = nil
    c.downto(c-half_period) { |i|
      if a[i]<f then left_shoulder=i; break end
    }
    if left_shoulder.nil? or right_shoulder.nil? then
      x_height = sane_x_height
    else
      x_height = right_shoulder-left_shoulder
      if x_height>0.6*line_spacing or x_height<sane_x_height*0.5 then
        # ... fails sanity check; the 0.5 in the second condition is to allow for the possibility that the user failed
        #     to override the default of spacing_multiple=1 but in fact it's double-spaced
        x_height = sane_x_height
      end
    end
  end

  return x_height
end

def estimate_line_spacing(proj,proj_windowed,n,nn,guess_dpi,guess_font_size,spacing_multiple,window,verbosity)
  if verbosity>=3 then make_graph("proj.pdf",nil,proj,"row","projection of left half") end
  # The projection looks pretty much like a square wave, the main deviation from a square wave shape being that the top has a deep indentation
  # near its middle.

  guess_period = 0.0171*guess_dpi*guess_font_size*spacing_multiple
  # The constant in front is derived from real-world data: took one of my books (output from LaTeX) and found that with an 11-point font,
  # 12 lines were 57.5 mm. Calculation is then (57.5 mm)(1/12)(1/11)(1/25.4 mm). For the Giles Odyssey book, in the archive.org scan, this
  # produces a guessed period of about 100 pixels, whereas the actual period is about 70 pixels. This seems kind of reasonable, since
  # that book seems to have been in a tiny pocketbook format and a fairly small font. The Cheng+cepstrum algorithm seems quite robust,
  # may still work even if this estimate is off by a factor of 2 or something.

  if verbosity>=3 then print "guess_period=#{guess_period}\n" end
  cheng_period = estimate_line_spacing_cheng_comb(proj,proj_windowed,window,nn,guess_period,1.4,verbosity)
  if verbosity>=3 then print "cheng_period=#{cheng_period}\n" end

  # Now refine the estimate using the cepstrum technique.
  guess_freq = (nn/cheng_period).round
  tol = 0.1
  min_freq = (guess_freq*(1-tol)).round
  max_freq = (guess_freq*(1+tol)).round
  if min_freq==guess_freq then min_freq=guess_freq-1 end
  if min_freq<3 then min_freq=3 end # shouldn't actually happen
  if max_freq==guess_freq then max_freq=guess_freq+1 end
  if max_freq>nn-1 then max_freq=nn-1 end
  if verbosity>=3 then print "inputs to cepstrum: min_freq=#{min_freq}, max_freq=#{max_freq}\n" end
  period = estimate_line_spacing_cepstrum(proj,proj_windowed,window,nn,cheng_period,guess_freq,min_freq,max_freq,verbosity)

  if verbosity>=2 then print "Line spacing is estimated to have period #{period}.\n" end

  return period
end

def estimate_line_spacing_cheng_comb(proj,proj_windowed,window,nn,guess_period,period_slop,verbosity)
  # Differentiate and square.
  n = proj.length
  y = []
  0.upto(n-2) { |j|
    a = proj[j+1]-proj[j]
    if a<0.0 then a=0 end
    y.push(a**2)
  }

  if verbosity>=3 then make_graph("sq_diff.pdf",nil,y,"row","y'^2") end

  period_lo = (guess_period/period_slop).round
  period_hi = (guess_period*period_slop).round
  if period_lo<2 then period_lo=2 end
  # Convolve with a bank of 3-tooth comb filter and look for max energy. This is an algorithm that apparently gives pretty
  # robust results when detecting tempo of music:
  # Kileen Cheng et al., "Beat This, A Beat Synchronization Project"
  # https://www.clear.rice.edu/elec301/Projects01/beat_sync/beatalgo.html
  # In some cases it gives double the actual period.
  # My implementation is a little slow, could be sped up using fft for convolution.
  n_teeth = 3
  tooth_width = (guess_period*0.05).round
  if tooth_width<1 then tooth_width=1 end
  results_energy = []
  results_periods = []
  if verbosity>=3 then print "Cheng comb, length=#{y.length}, period=#{period_lo}-#{period_hi}, n_teeth=#{n_teeth}, tooth_width=#{tooth_width}\n" end
  period_lo.upto(period_hi) { |period|
    results_energy_this_period = []
    results_inputs_this_period = []
    0.upto(period-1) { |phase|
      energy = 0.0
      0.upto(n_teeth) { |tooth|
        0.upto(tooth_width-1) { |i|
          k = tooth*period+i+phase
          if k>y.length-1 then next end
          energy += y[k] # don't square y, it's already a squared amplitude
        }
      }
      results_energy_this_period.push(energy)
      results_inputs_this_period.push(phase)
    } # end loop over phases
    m,energy = greatest(results_energy_this_period)
    results_energy.push(energy)
    results_periods.push(period)
  }
  m,energy = greatest(results_energy)
  period = results_periods[m]
  if verbosity>=3 then print "Cheng comb gives best period=#{period}\n" end
  if verbosity>=3 then make_graph("cheng.pdf",results_periods,results_energy,"period","energy") end
  return period
end

def estimate_line_spacing_cepstrum(proj_raw,proj_windowed,window,nn,guess_period,guess_freq,min_freq,max_freq,verbosity)
  # In the example I looked at, the raw fft basically looks like a huge low-frequency peak, and then harmonics 1, 3, 4, and 6.
  # The low-frequency peak is ragged enough that it has local maxima that are the biggest maxima in the spectrum.
  # The raw fft had a peak at about channel 16. The cepstrum's corresponding peak was at channel 71, and was pretty clean-looking,
  # so it was pretty clear that it was giving a higher-resolution determination of the peak.
  proj = proj_windowed
  avg,sd = find_mean_sd(proj)
  if proj.length<nn then die("hey, proj was already supposed to be windowed and padded in windowing_and_padding") end
  fourier = fft(proj)
  if verbosity>=3 then graph_fft(fourier,max_freq,nn) end
  
  # cepstrum analysis:
  aa = []
  0.upto(nn-1) { |ff|
    if ff>=min_freq*0.7 and ff<nn/2 then
      v = fourier[ff].abs
    else
      v = 0.0
    end
    aa.push(v)
  }
  cepstrum = fft(aa).map {|a| a.abs}
  min_period = (nn/max_freq).round
  max_period = (nn/min_freq).round
  best_cepstrum,garbage = greatest_in_range(cepstrum,min_period,max_period)
  if verbosity>=3 then print "best period from cepstrum = #{best_cepstrum}\n" end


  graph_x = []
  graph_y = []
  0.upto(nn/4-1) { |t|
    c = cepstrum[t].abs
    graph_x.push(t)
    graph_y.push(c)
  }
  if verbosity>=3 then make_graph("cepstrum.pdf",graph_x,graph_y,"period","cepstrum") end

  period = fit_gaussian_to_peak(cepstrum,best_cepstrum-2,best_cepstrum+2,[best_cepstrum,1,cepstrum[best_cepstrum]])
  if verbosity>=3 then print "gaussian fit = #{period}\n" end

  return period
end

def fit_gaussian_to_peak(data,lo,hi,guesses)
  # Given an array y_values and guessed parameters of a gaussian, refine the fit using least-squares.
  # Return the centroid.
  # The result is a real number and is hoped to have resolution better than one channel.
  mu,sigma,height = guesses
  x_values = []
  y_values = []
  lo.upto(hi) { |i|
    x_values.push(i)
    y_values.push(data[i])
  }
  x = x_values.join(",")
  y = y_values.join(",")
  r = <<-"R_CODE"
    library(minpack.lm)
    xvalues <- c(#{x})
    yvalues <- c(#{y})
    model <- nlsLM(yvalues ~ height*exp(-0.5*(xvalues-mu)^2/sigma^2),start = list(mu=#{mu},sigma=#{sigma},height=#{height}))
    cat("__output__",coef(summary(model))["mu","Estimate"],"\n")
  R_CODE
  return run_r_code(r).to_f
end

def graph_fft(fourier,max_freq,nn)
  graph_x = []
  graph_y = []
  0.upto(nn-1) { |ff|
    a = fourier[ff].abs
    if ff>0 and (ff<nn/8 or ff<max_freq) then
      graph_x.push(ff)
      graph_y.push(a)
    end
  }
  make_graph("fft.pdf",graph_x,graph_y,"#{nn}/spacing","r.m.s. amplitude")
end
