def estimate_line_spacing(image,guess_dpi:30,guess_font_size:12,window:'none')
  # This could probably be made less sensitive to rotation by taking power spectra on vertical strips and adding those.
  n = image.height
  proj = []
  0.upto(image.height-1) { |j|
    x = 0.0
    0.upto(image.width-1) { |i|
      x = x+color_to_ink(image[i,j])
    }
    proj.push(x)
  }
  # Windowing:
  0.upto(image.height-1) { |j|
    x = 2.0*Math::PI*j.to_f/n
    if window=='none' then w = 1.0 end
    if window=='hann' then w = 0.5*(1-Math::cos(x)) end
    proj[j] = proj[j]*w
  }
  pow2 = (Math::log(n)/Math::log(2.0)).to_i
  if 2**pow2<n then pow2=pow2+1 end
  nn = 2**pow2
  avg = 0.0
  0.upto(n-1) { |i| avg=avg+proj[i] }
  avg = avg/n
  while proj.length<nn do proj.push(avg) end
  fourier = fft(proj)
  # The following is just so we have some idea what frequency range to look at.
  guess_period = 0.04*guess_dpi*guess_font_size
  guess_freq = (nn*0.5/guess_period).to_i # Is the 0.5 right, Nyquist frequency?
  min_freq = guess_freq/3
  if min_freq<3 then min_freq=3 end
  max_freq = guess_freq*3
  if max_freq>nn-1 then max_freq=nn-1 end
  max = 0.0
  best = -1
  print "guess_period=#{guess_period}, min_freq=#{min_freq}, max period=#{nn/min_freq.to_f}\n" # qwe
  graph_x = []
  graph_y = []
  0.upto(nn-1) { |ff|
    a = fourier[ff].abs
    if ff>0 and (ff<nn/8 or ff<max_freq) then
      graph_x.push(ff)
      graph_y.push(a)
    end
    if ff<min_freq or ff>max_freq then next end
    if a>max then max=a; best=ff end
  }
  period = nn/best.to_f
  print "fft period=#{period}, best frequency=#{nn.to_f/period}\n"
  graph_filename = "fft.pdf"
  make_graph(graph_filename,graph_x,graph_y,"#{nn}/spacing","r.m.s. amplitude")
  print "Graph written to #{graph_filename}\n"
  return period
end
