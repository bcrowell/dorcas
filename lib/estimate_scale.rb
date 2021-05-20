def estimate_line_spacing(image,guess_dpi:30,guess_font_size:12,window:'hann')
  proj = project_onto_y(image,0,image.width/2-1)
  print "Analyzing line spacing based on the left half of the page.\n"
  # ... Doing only the left half of the image serves two purposes. If the image is rotated a little, then this mitigates the problem.
  #     Also, if there are two columns of text, then this will pick up only one. This could of course be the wrong choice in
  #     some cases, e.g., if there's a picture on the left side of the page.
  make_graph("proj.pdf",nil,proj,"row","projection of left half")
  # The projection looks pretty much like a square wave, the main deviation from a square wave shape being that the top has a deep indentation
  # near its middle.

  # The following is just so we have some idea what frequency range to look at.
  n = proj.length
  avg,sd = find_mean_sd(proj)
  pow2 = (Math::log(n)/Math::log(2.0)).to_i
  if 2**pow2<n then pow2=pow2+1 end
  nn = 2**pow2
  proj_windowed = windowing_and_padding(proj,window,nn,avg)
  guess_period = 0.08*guess_dpi*guess_font_size

  print "guess_period=#{guess_period}\n"
  cheng_period = estimate_line_spacing_cheng_comb(proj,proj_windowed,window,nn,guess_period)
  print "cheng_period=#{cheng_period}\n"

  # Now refine the estimate using the cepstrum technique.
  guess_freq = (nn/cheng_period).round
  tol = 0.1
  min_freq = (guess_freq*(1-tol)).round
  max_freq = (guess_freq*(1+tol)).round
  if min_freq==guess_freq then min_freq=guess_freq-1 end
  if min_freq<3 then min_freq=3 end # shouldn't actually happen
  if max_freq==guess_freq then max_freq=guess_freq+1 end
  if max_freq>nn-1 then max_freq=nn-1 end
  print "inputs to cepstrum: min_freq=#{min_freq}, max_freq=#{max_freq}\n"
  period = estimate_line_spacing_cepstrum(proj,proj_windowed,window,nn,cheng_period,guess_freq,min_freq,max_freq)

  print "period=#{period}, best frequency=#{nn.to_f/period}\n"

  return period
end

def estimate_line_spacing_cheng_comb(proj,proj_windowed,window,nn,guess_period)
  # Differentiate and square.
  n = proj.length
  y = []
  0.upto(n-2) { |j|
    a = proj[j+1]-proj[j]
    if a<0.0 then a=0 end
    y.push(a**2)
  }

  make_graph("sq_diff.pdf",nil,y,"row","y'^2")

  period_lo = (guess_period*0.3).round
  period_hi = (guess_period*3.0).round
  if period_lo<2 then period_lo=2 end
  # Convolve with a bank of 3-tooth comb filter and look for max energy. This is an algorithm that apparently gives pretty
  # robust results when detecting tempo of music:
  # Kileen Cheng et al., "Beat This, A Beat Synchronization Project"
  # https://www.clear.rice.edu/elec301/Projects01/beat_sync/beatalgo.html
  # My implementation is a little slow, could be sped up using fft for convolution.
  n_teeth = 3
  tooth_width = (guess_period*0.05).round
  if tooth_width<1 then tooth_width=1 end
  results_energy = []
  results_periods = []
  print "Cheng comb, length=#{y.length}, period=#{period_lo}, #{period_hi}, n_teeth=#{n_teeth}, tooth_width=#{tooth_width}\n"
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
  print "Cheng comb gives best period=#{period}\n"
  make_graph("cheng.pdf",results_periods,results_energy,"period","energy")
  return period
end

def estimate_line_spacing_cepstrum(proj_raw,proj_windowed,window,nn,guess_period,guess_freq,min_freq,max_freq)
  # In the example I looked at, the raw fft basically looks like a huge low-frequency peak, and then harmonics 1, 3, 4, and 6.
  # The low-frequency peak is ragged enough that it has local maxima that are the biggest maxima in the spectrum.
  # The raw fft had a peak at about channel 16. The cepstrum's corresponding peak was at channel 71, and was pretty clean-looking,
  # so it was pretty clear that it was giving a higher-resolution determination of the peak.
  proj = proj_windowed
  avg,sd = find_mean_sd(proj)
  while proj.length<nn do proj.push(avg) end
  fourier = fft(proj)
  graph_fft(fourier,max_freq,nn)
  
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
  cepstrum = fft(aa)
  min_period = (nn/max_freq).round
  max_period = (nn/min_freq).round
  best_cepstrum,garbage = greatest_in_range(cepstrum,min_period,max_period,filter:lambda {|a| a.abs})
  print "best period from cepstrum = #{best_cepstrum}\n"


  graph_x = []
  graph_y = []
  0.upto(nn/4-1) { |t|
    c = cepstrum[t].abs
    graph_x.push(t)
    graph_y.push(c)
  }
  make_graph("cepstrum.pdf",graph_x,graph_y,"period","cepstrum")

  return best_cepstrum
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
