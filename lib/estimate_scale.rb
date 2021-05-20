def estimate_line_spacing(image,guess_dpi:30,guess_font_size:12,window:'hann')
  proj = project_onto_y(image,0,image.width/2-1)
  print "Analyzing line spacing based on the left half of the page.\n"
  # ... Doing only the left half of the image serves two purposes. If the image is rotated a little, then this mitigates the problem.
  #     Also, if there are two columns of text, then this will pick up only one. This could of course be the wrong choice in
  #     some cases, e.g., if there's a picture on the left side of the page.
  make_graph("proj.pdf",nil,proj,"row","projection of left half")
  # The projection looks pretty much like a square wave, the main deviation from a square wave shape being that the top has a deep indentation
  # near its middle.
  return estimate_line_spacing_old(proj,guess_dpi,guess_font_size,window)
end

def estimate_line_spacing_new(proj,guess_dpi,guess_font_size,window)
  # Differentiate and square.
  0.upto(n-2) { |j|
    y[j] = (proj[j+1]-proj[j])**2
  }
  proj = windowing(proj,window)
  fourier = fft(proj)

end

def estimate_line_spacing_old(proj,guess_dpi,guess_font_size,window)
  # This could probably be made less sensitive to rotation by taking power spectra on vertical strips and adding those.
  # In the example I looked at, the raw fft basically looks like a huge low-frequency peak, and then harmonics 1, 3, 4, and 6.
  # The low-frequency peak is ragged enough that it has local maxima that are the biggest maxima in the spectrum.
  # The raw fft had a peak at about channel 16. The cepstrum's corresponding peak was at channel 71, and was pretty clean-looking,
  # so it was pretty clear that it was giving a higher-resolution determination of the peak.
  n = proj.length
  proj = windowing(proj,window)
  pow2 = (Math::log(n)/Math::log(2.0)).to_i
  if 2**pow2<n then pow2=pow2+1 end
  nn = 2**pow2
  avg = 0.0
  0.upto(n-1) { |i| avg=avg+proj[i] }
  avg = avg/n
  while proj.length<nn do proj.push(avg) end
  fourier = fft(proj)
  # Optional high-pass filter.
  # Adding a first-order high-pass filter makes the spectrum much cleaner. The low-frequency crap goes away. The harmonics
  # now become about equal in amplitude, as you'd expect for a square wave.
  # Although this looks much better to the human eye, it works worse for the algorithm, which now picks out harmonics instead of the fundamental.
  # So instead do "half of" a first-order filter, i.e., multiply the spectrum by 1/sqrt(freq). This keeps the harmonics lower than the
  # fundamental, but somewhat cleans up the low-frequency noise.
  if true then
  0.upto(nn-1) { |ff|
    fourier[ff] *= Math::sqrt(ff)
  }
  end
  # The following is just so we have some idea what frequency range to look at.
  guess_period = 0.08*guess_dpi*guess_font_size
  guess_freq = (nn/guess_period).to_i
  min_freq = guess_freq/3
  if min_freq<3 then min_freq=3 end
  max_freq = guess_freq*3
  if max_freq>nn-1 then max_freq=nn-1 end
  print "guess_period=#{guess_period}, min_freq=#{min_freq}, max period=#{nn/min_freq.to_f}\n" # qwe
  best,max = greatest_in_range(fourier,min_freq,max_freq,filter:lambda {|x| x.abs})
  period = nn/best.to_f
  print "fft period=#{period}, best frequency=#{nn.to_f/period}\n"

  graph_fft(fourier,max_freq,nn)
  
  aa = []
  0.upto(nn-1) { |ff|
    if ff>=min_freq and ff<nn/2 then
      v = fourier[ff].abs
    else
      v = 0.0
    end
    aa.push(v)
  }
  cepstrum = fft(aa)
  graph_x = []
  graph_y = []
  max_cepstrum = 0.0
  best_cepstrum = nil
  0.upto(nn/4-1) { |t|
    c = cepstrum[t].abs
    graph_x.push(t)
    graph_y.push(c)
    if t<period*0.8 or t>period*1.2 then next end
    if c>max_cepstrum then max_cepstrum=c; best_cepstrum=t end
  }
  graph_filename = "cepstrum.pdf"
  make_graph(graph_filename,graph_x,graph_y,"period","cepstrum")
  print "Cepstrum graph written to #{graph_filename}. Best period=#{best_cepstrum}.\n"

  #return period
  return best_cepstrum # seems better, has much higher resolution
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
  graph_filename = "fft.pdf"
  make_graph(graph_filename,graph_x,graph_y,"#{nn}/spacing","r.m.s. amplitude")
  print "Graph written to #{graph_filename}\n"
end
